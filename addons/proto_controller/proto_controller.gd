extends CharacterBody3D

signal inventory_changed(new_inventory)
signal coins_changed(coins_amount)
signal item_changed(item_data: ItemData)
signal inventory_closed

# --- REFERENCES ---
@onready var head: Node3D = $Head
@onready var hand_position: Node3D = $Head/Camera3D/HandPosition
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var collider: CollisionShape3D = $Collider
@onready var camera: Camera3D = $Head/Camera3D
@onready var anim_player = $player/AnimationPlayer

# --- NEW UI REFERENCES ---
@onready var inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI
@onready var hotbar_controller: Node = %InventoryController/CanvasLayer/HotbarUI
@export var game_info_ui: Control = null

# --- SETTINGS ---
@export_group("Movement")
@export var base_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 4.5
@export var look_speed: float = 0.002
var gravity_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# --- STATE ---
var look_rotation: Vector2 = Vector2.ZERO
var seat_target: Node3D = null 
var is_menu_open: bool = false
var is_locked: bool = false 
@onready var external_inventory_node = $CanvasLayer/ExternalInventoryUI
@onready var water_overlay = $CanvasLayer/GameInfo/WaterVision
@onready var standard_overlay = $CanvasLayer/GameInfo/StandardVision

# Fishing / Limits
var look_limit_center: Vector2 = Vector2.ZERO
var is_look_limited: bool = false

# Inventory
var current_tool: Node3D = null
var current_slot: int = 0
var inventory_slots: Array = [] 
const MAX_SLOTS = 36
@export var world_item_scene: PackedScene

@export var coins: int = 0:
	set(value):
		coins = value
		coins_changed.emit(coins)
			
func _ready() -> void:
	# 1. Setup Mouse and Rotation
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	# 2. Setup Inventory
	inventory_slots.resize(MAX_SLOTS)
	inventory_slots.fill(null)
	
	# 3. Auto-find HUD if not assigned
	if not game_info_ui:
		var found_info = get_tree().get_nodes_in_group("game_info")
		if found_info: game_info_ui = found_info[0]
		
	# 4. Connect Coins -> Game Info
	if game_info_ui:
	# Existing coins connection
		if not coins_changed.is_connected(game_info_ui.update_coins_display):
			coins_changed.connect(game_info_ui.update_coins_display)
		game_info_ui.update_coins_display(coins)
	
		# NEW: Connect Item Changed to Item Display
		if game_info_ui.has_method("update_item_display"):
			if not item_changed.is_connected(game_info_ui.update_item_display):
				item_changed.connect(game_info_ui.update_item_display)
				
			# Initial UI update (starts empty)
			item_changed.emit(null)
	
	_refresh_inventory()
	coins_changed.emit(coins)
	var head_detector = $Head/Camera3D/HeadDetector
	# Water vision
	head_detector.area_entered.connect(_on_head_detector_area_entered)
	head_detector.area_exited.connect(_on_head_detector_area_exited)
	water_overlay.visible = false
	standard_overlay.visible = true

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	# 1. EMERGENCY ESCAPE & MOUSE RELEASE
	if event.is_action_pressed("ui_cancel"): # Usually Esc
		if is_menu_open:
			toggle_inventory(false)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	# 2. INVENTORY TOGGLE (TAB/I)
	if event.is_action_pressed("inventory"):
		toggle_inventory(!is_menu_open)
	
	if event.is_action_pressed("drop_item") and not is_menu_open:
		drop_current_item()

	# 3. MOUSE LOOK LOGIC
	if event is InputEventMouseMotion and not is_menu_open:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			look_rotation.x -= event.relative.y * look_speed
			look_rotation.y -= event.relative.x * look_speed
			
			look_rotation.x = clamp(look_rotation.x, deg_to_rad(-75), deg_to_rad(85))
			
			if is_look_limited:
				look_rotation.x = clamp(look_rotation.x, look_limit_center.x - deg_to_rad(45), look_limit_center.x + deg_to_rad(45))
				look_rotation.y = clamp(look_rotation.y, look_limit_center.y - deg_to_rad(45), look_limit_center.y + deg_to_rad(45))
			elif seat_target:
				look_rotation.y = clamp(look_rotation.y, deg_to_rad(-100), deg_to_rad(100))

			if seat_target:
				head.rotation.y = look_rotation.y
				head.rotation.x = look_rotation.x
			else:
				rotation.y = look_rotation.y
				head.rotation.x = look_rotation.x
				head.rotation.y = 0 

	# 4. MOUSE CAPTURE ON CLICK
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_menu_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	# 5. INTERACTION
	if event.is_action_pressed("interact"):
		try_interact()

	# 6. TOOL ACTIONS (Disabled when menu is open)
	if current_tool and not is_menu_open:
		if event.is_action_pressed("fire_primary") and current_tool.has_method("primary_action"):
			current_tool.primary_action()
		
		if event.is_action_pressed("fire_secondary") and current_tool.has_method("secondary_action"):
			current_tool.secondary_action(true)
		elif event.is_action_released("fire_secondary") and current_tool.has_method("secondary_action"):
			current_tool.secondary_action(false)

	# 7. HOTKEYS
	if not is_menu_open:
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				_change_active_slot(-1)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_change_active_slot(1)
		for i in range(1, 10):
			if event.is_action_pressed("hotkey_" + str(i)):
				select_slot(i - 1)
				
func _change_active_slot(direction: int) -> void:
	# 1. Prevent switching if the tool is busy (e.g., fishing)
	if current_tool and current_tool.has_method("is_fishing") and current_tool.is_fishing:
		return
	
	# 2. Calculate the new index (wrapping between 0 and 8 for the hotbar)
	# posmod ensures that scrolling up from 0 wraps to 8 correctly
	var new_index = posmod(current_slot + direction, 9)
	
	# 3. Use your existing select_slot function to handle the actual logic
	select_slot(new_index)

func toggle_inventory(open: bool):
	is_menu_open = open
	is_locked = open
	
	# 1. Handle Player Inventory
	if inventory_controller:
		inventory_controller.visible = open
	
	# 2. Handle External Inventory
	if external_inventory_node:
		if not open:
			external_inventory_node.visible = false
			var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
			if external_ui and external_ui.current_inventory:
				# Tell the chest it's closing
				if external_ui.current_inventory.has_method("on_player_closed_npc"):
					external_ui.current_inventory.on_player_closed_npc(self)
		
				# Clear the reference so we don't accidentally edit it later
				external_ui.current_inventory = null
	
	# 3. Handle Hotbar (Always visible)
	if hotbar_controller:
		hotbar_controller.visible = true 
	
	# 4. Handle Mouse and Movement
	if open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		interact_ray.enabled = false
		if is_on_floor():
			velocity.x = 0
			velocity.z = 0 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		interact_ray.enabled = true

# --- PHYSICS ---
func _physics_process(delta: float) -> void:
	if seat_target:
		global_transform = seat_target.global_transform
		# Play a sitting/rowing animation if you have one
		if anim_player.current_animation != "Pirate_Sit":
			anim_player.play("Pirate_Sit", 0.2)
		return 
	
	if is_menu_open or is_locked: 
		if not is_on_floor(): velocity += (get_gravity() * gravity_multiplier) * delta
		move_and_slide()
		#anim_player.play("RESET", 0.3) # Stay in idle if locked
		return
	
	if not is_on_floor(): 
		velocity += get_gravity() * delta
		# Optional: anim.play("Player_jump_loop")
	
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var is_sprinting = Input.is_action_pressed("sprint")
	var speed = (sprint_speed if is_sprinting else base_speed) * speed_multiplier
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
		
		# Keep your blend for starting to walk (feels natural)
		anim_player.play("Player_Walking", 0.3)
		anim_player.speed_scale = (speed / base_speed) * 2.0
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)
		
		if current_tool:
			if current_tool.has_method("is_fishing") and current_tool.is_fishing:
				pass 
			elif current_tool.is_in_group("fishing_rod"):
				anim_player.play("holding_rod", 0.3)
				anim_player.speed_scale = 1.0
			else:
				anim_player.play("player_idle", 0.2)
				anim_player.speed_scale = 1.0
		else:
			anim_player.play("player_idle", 0.2)
			anim_player.speed_scale = 1.0

	move_and_slide()

# --- INTERACTION ---
func try_interact():
	if seat_target:
		exit_boat_mode()
		return

	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		
		# Look for 'interact' on the target or its parent (in case we hit a child mesh)
		if target.has_method("interact"):
			target.interact(self)
		elif target.get_parent().has_method("interact"):
			target.get_parent().interact(self)

# --- INVENTORY ---
func add_to_inventory(item: ItemData):
	var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
	var external_inventory = external_ui.current_inventory if (external_ui and external_ui.visible) else null

	# 1. Check for existing stacks (Player + Chest)
	if item.stackable:
		# Check Player
		for slot in inventory_slots:
			if slot and slot["data"] == item and slot["quantity"] < item.max_stack_size:
				slot["quantity"] += 1
				_refresh_inventory()
				return 
		
		# Check Chest (if open)
		if external_inventory:
			for slot in external_inventory.inventory_slots:
				if slot and slot["data"] == item and slot["quantity"] < item.max_stack_size:
					slot["quantity"] += 1
					external_ui.update_ui(external_inventory.inventory_slots)
					return

	# 2. Find empty slot in Player first
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			inventory_slots[i] = { "data": item, "quantity": 1 }
			_refresh_inventory()
			return

	# 3. If Player is full, find empty slot in Chest
	if external_inventory:
		for i in range(external_inventory.inventory_slots.size()):
			if external_inventory.inventory_slots[i] == null:
				external_inventory.inventory_slots[i] = { "data": item, "quantity": 1 }
				external_ui.update_ui(external_inventory.inventory_slots)
				return
				
	print("Everything (including the chest) is full!")

func _refresh_inventory():
	inventory_changed.emit(inventory_slots)
	
	if hotbar_controller and hotbar_controller.has_method("update_inventory_ui"):
		# This slice now contains dictionaries
		hotbar_controller.update_inventory_ui(inventory_slots.slice(0, 9))
	
	if inventory_controller and inventory_controller.has_method("update_inventory_ui"):
		# This slice now contains dictionaries
		inventory_controller.update_inventory_ui(inventory_slots.slice(9, 36))

# In your Player script
func handle_global_swap(from_id: int, to_id: int):
	# Find the chest UI to see if a chest is currently open
	var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
	var chest = external_ui.current_inventory if external_ui else null

	# GET DATA
	var get_data = func(id: int):
		if id < 36: return inventory_slots[id]
		elif chest: return chest.inventory_slots[id - 36]
		return null

	# SET DATA
	var set_data = func(id: int, data):
		if id < 36: inventory_slots[id] = data
		elif chest: chest.inventory_slots[id - 36] = data

	# SWAP
	var from_data = get_data.call(from_id)
	var to_data = get_data.call(to_id)
	
	set_data.call(from_id, to_data)
	set_data.call(to_id, from_data)
	
	# REFRESH
	_refresh_inventory()
	if external_ui and chest:
		external_ui.update_ui(chest.inventory_slots)
	select_slot(current_slot)

func select_slot(index: int):
	# 1. Prevent switching if the tool is busy
	if current_tool and "is_fishing" in current_tool and current_tool.is_fishing: 
		return
		
	current_slot = index
	
	# 2. Update the Hotbar UI highlight
	if hotbar_controller and hotbar_controller.has_method("set_active_slot"): 
		hotbar_controller.set_active_slot(index)
	
	# 3. Handle Equipping and UI Update
	if index >= 0 and inventory_slots[index] != null:
		var item_to_equip = inventory_slots[index]["data"]
		equip_item(item_to_equip)
		item_changed.emit(item_to_equip) # Tell UI what we are holding
	else:
		unequip_hand()
		item_changed.emit(null) # Tell UI hand is empty

func equip_item(item_data: ItemData):
	unequip_hand()
	
	for child in %HandSocket.get_children():
		child.queue_free()
		
	if not item_data.equippable_scene:
		return

	var new_tool = item_data.equippable_scene.instantiate()
	%HandSocket.add_child(new_tool)
	
	current_tool = new_tool
	if current_tool.has_method("setup"): 
		current_tool.setup(self)
		
	if current_tool.has_method("set_item_data"):
		current_tool.set_item_data(item_data)

func get_item_at_index(id: int):
	if id >= 0 and id < inventory_slots.size():
		return inventory_slots[id]
	return null
	
func attach_lure_to_rod(lure_id: int, rod_id: int):
	# Use 'as Dictionary' to tell Godot what type to expect
	var lure_slot = get_item_at_index(lure_id) as Dictionary
	var rod_slot = get_item_at_index(rod_id) as Dictionary
	
	# Only proceed if BOTH are actually dictionaries (not null)
	if lure_slot and rod_slot:
		var lure_data = lure_slot["data"]
		var rod_data = rod_slot["data"]
		
		if lure_data is LureData and rod_data is RodData:
			if not rod_data.resource_path.is_empty(): 
				rod_data = rod_data.duplicate()
				inventory_slots[rod_id]["data"] = rod_data
			
			rod_data.lure = lure_data
			inventory_slots[lure_id] = null
			
			_refresh_inventory()
			if current_slot == rod_id:
				select_slot(rod_id)
			
			print("Successfully attached ", lure_data.name, " to ", rod_data.name)
	else:
		print("Lure or Rod slot was empty - cannot attach.")

func unequip_hand():
	if current_tool and current_tool.has_method("unequip"):
		current_tool.unequip()
	current_tool = null
	for child in hand_position.get_children():
		child.queue_free()

# --- BOAT MODES ---
func enter_boat_mode(target_seat: Node3D):
	select_slot(-1)
	seat_target = target_seat
	is_locked = true
	collider.disabled = true
	global_transform = seat_target.global_transform
	look_rotation = Vector2.ZERO 
	head.rotation = Vector3.ZERO

func exit_boat_mode():
	seat_target = null
	is_locked = false
	collider.disabled = false
	
	var boat_yaw = global_rotation.y
	look_rotation.y = boat_yaw
	look_rotation.x = 0
	
	global_position.y += 1.5
	rotation.y = boat_yaw
	head.rotation = Vector3.ZERO

func open_external_inventory(chest):
	if external_inventory_node and external_inventory_node.has_method("open_container"):
		external_inventory_node.open_container(chest)
		toggle_inventory(true)

func _on_head_detector_area_entered(area):
	if area.is_in_group("water"):
		water_overlay.visible = true
		standard_overlay.visible = false
		water_overlay.material.set_shader_parameter("blue_tint", Color(0.0, 0.4, 0.8, 0.4))
		
		gravity_multiplier = 0.2
		speed_multiplier = 0.6 # 80% reduction in speed
		velocity.y *= 0.2

func _on_head_detector_area_exited(area):
	if area.is_in_group("water"):
		water_overlay.visible = false
		standard_overlay.visible = true
		water_overlay.material.set_shader_parameter("blue_tint", Color(0.0, 0.4, 0.8, 0.0))
		
		gravity_multiplier = 1.0
		speed_multiplier = 1.0 # Reset to full speed

func remove_lure_from_rod(rod_slot_id: int):
	var item_entry = get_item_at_index(rod_slot_id) as Dictionary
	
	if item_entry and item_entry["data"] is RodData:
		var rod_data = item_entry["data"]
		
		if rod_data.lure != null:
			var lure_to_pop = rod_data.lure
			var empty_slot = find_first_empty_slot()
			
			if empty_slot != -1:
				# 1. Remove the lure from the rod data
				rod_data.lure = null
				
				# 2. Add the lure to the empty slot
				inventory_slots[empty_slot] = {
					"data": lure_to_pop,
					"quantity": 1
				}
				
				# 3. Refresh UI and re-select the rod to update the hand model/lure display
				_refresh_inventory()
				if current_slot == rod_slot_id:
					select_slot(rod_slot_id)
					
				print("Lure removed and placed in slot: ", empty_slot)
			else:
				print("Inventory full! Cannot remove lure.")
				
func find_first_empty_slot() -> int:
	# Iterate through all player slots (0 to 35)
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			return i
	return -1 # Returns -1 if no space is found

func drop_current_item():
	var slot_data = inventory_slots[current_slot]
	if slot_data == null: return
	
	var dropped_item = world_item_scene.instantiate()
	
	# SET DATA FIRST
	dropped_item.item_data = slot_data["data"]
	
	# THEN ADD TO WORLD
	get_parent().add_child(dropped_item)
	
	dropped_item.global_position = head.global_position + (-head.global_transform.basis.z * 1.5)
	
	# Toss it
	var throw_direction = -head.global_transform.basis.z + Vector3(0, 0.5, 0)
	dropped_item.apply_central_impulse(throw_direction * 5.0)

	# Inventory Cleanup...
	if slot_data["quantity"] > 1:
		slot_data["quantity"] -= 1
	else:
		# If it was the last one, clear the slot and unequip
		inventory_slots[current_slot] = null
		unequip_hand()
		item_changed.emit(null)

	_refresh_inventory()
