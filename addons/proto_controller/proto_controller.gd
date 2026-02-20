extends CharacterBody3D

signal inventory_changed(new_inventory)
signal coins_changed(coins_amount)
signal inventory_closed

# --- REFERENCES ---
@onready var head: Node3D = $Head
@onready var hand_position: Node3D = $Head/Camera3D/HandPosition
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var collider: CollisionShape3D = $Collider
@onready var camera: Camera3D = $Head/Camera3D

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

# --- STATE ---
var look_rotation: Vector2 = Vector2.ZERO
var seat_target: Node3D = null 
var is_menu_open: bool = false
var is_locked: bool = false 
@onready var external_inventory_node = $CanvasLayer/ExternalInventoryUI

# Fishing / Limits
var look_limit_center: Vector2 = Vector2.ZERO
var is_look_limited: bool = false

# Inventory
var current_tool: Node3D = null
var current_slot: int = 0
var inventory_slots: Array = [] 
const MAX_SLOTS = 36

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
		if game_info_ui.has_method("update_coins_display"):
			if not coins_changed.is_connected(game_info_ui.update_coins_display):
				coins_changed.connect(game_info_ui.update_coins_display)
			game_info_ui.update_coins_display(coins)
		else:
			printerr("ERROR: Game Info UI missing function 'update_coins_display'")
	
	_refresh_inventory()
	coins_changed.emit(coins)

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

	# 3. MOUSE LOOK LOGIC
	if event is InputEventMouseMotion and not is_menu_open:
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			look_rotation.x -= event.relative.y * look_speed
			look_rotation.y -= event.relative.x * look_speed
			
			look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
			
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
		for i in range(1, 10):
			if event.is_action_pressed("hotkey_" + str(i)):
				select_slot(i - 1)

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
		return 
	
	if is_menu_open or is_locked: 
		if not is_on_floor(): velocity += get_gravity() * delta
		move_and_slide()
		return
	
	if not is_on_floor(): velocity += get_gravity() * delta
	
	if Input.is_action_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var speed = sprint_speed if Input.is_action_pressed("sprint") else base_speed
	var direction = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if direction:
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		velocity.z = move_toward(velocity.z, 0, speed)

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
		else:
			print("Hit something, but it has no interact method: ", target.name)

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

func select_slot(index: int):
	# 1. Prevent switching if the tool is busy (e.g., fishing)
	if current_tool and "is_fishing" in current_tool and current_tool.is_fishing: 
		return
		
	current_slot = index
	
	# 2. Update the Hotbar UI highlight
	if hotbar_controller and hotbar_controller.has_method("set_active_slot"): 
		hotbar_controller.set_active_slot(index)
	
	# 3. Handle Equipping from Dictionary
	# Check if the slot is not null (meaning it contains a dictionary)
	if inventory_slots[index] != null:
		# Extract the ItemData from the "data" key of the dictionary
		var item_to_equip = inventory_slots[index]["data"]
		equip_item(item_to_equip)
	else:
		# If the dictionary is null, the slot is empty
		unequip_hand()

func equip_item(item_data: ItemData):
	unequip_hand()
	if item_data.equippable_scene:
		current_tool = item_data.equippable_scene.instantiate()
		hand_position.add_child(current_tool)
		if current_tool.has_method("setup"): current_tool.setup(self)

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
