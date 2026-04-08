extends CharacterBody3D
class_name Player

signal coins_changed(coins_amount)
signal xp_changed(foraging_xp_amount, fishing_xp_amount)

# --- REFERENCES ---
@onready var camera_controller: CameraController = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand_socket: Node3D = %HandSocket
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var interact_ray_map: RayCast3D = $Head/Camera3D/InteractRayCast
@onready var collider: CollisionShape3D = $Collider
@onready var anim_player = $player/AnimationPlayer
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var anim_tree: AnimationTree = $player/AnimationTree

# --- UI REFERENCES ---
@onready var inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI
@onready var hotbar_controller: Node = %InventoryController/CanvasLayer/HotbarUI
@onready var settings_controller: Node = $CanvasLayer/Settings
@export var game_info_ui: Control = null
@onready var map_ui: Node = $CanvasLayer/MapUI
@onready var external_inventory_node = $CanvasLayer/ExternalInventoryUI
@onready var water_overlay = $CanvasLayer/GameInfo/WaterVision
@onready var standard_overlay = $CanvasLayer/GameInfo/StandardVision
@onready var crosshair = $CanvasLayer/GameInfo/Crosshair

# --- SETTINGS ---
@export_group("Movement")
@export var base_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 4.5
var gravity_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# --- STATE ---
var is_menu_open: bool = false
var is_settings_open: bool = false
var is_map_open: bool = false
var is_locked: bool = false 
var last_focused_target = null
var is_sprinting: bool = false

# Tool
var current_tool: Node3D = null

# Boat
var current_boat: RigidBody3D = null

# Player Level/Stats Section
@export var max_hp: int = 100
@export var max_stamina: int = 100
@export var strength: int = 0
@export var defense: int = 0
@export var hp: int = max_hp

@export var double_forage_chance: float = 0
@export var stamina: float = max_stamina:
	set(value):
		# Clamp ensures stamina stays between 0 and 100
		stamina = clamp(value, 0, max_stamina)
		
		# Automatically update UI whenever this variable changes
		if game_info_ui and game_info_ui.stamina_bar:
			game_info_ui.stamina_bar.update_stamina(stamina, max_stamina)
@export var stamina_drain_rate: float = 20.0  # Points per second while sprinting
@export var stamina_regen_rate: float = 10.0   # Points per second while resting

@export var foraging_xp: float = 1:
	set(value):
		foraging_xp = value
		xp_changed.emit(foraging_xp, fishing_xp)
var foraging_lvl: int = 0

@export var fishing_xp: float = 1:
	set(value):
		fishing_xp = value
		xp_changed.emit(foraging_xp, fishing_xp)
var fishing_lvl: int = 0


@export var coins: int = 0:
	set(value):
		coins = value
		coins_changed.emit(coins)
			
func _ready() -> void:
	state_machine.init(self)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	
	if not game_info_ui:
		var found_info = get_tree().get_nodes_in_group("game_info")
		if found_info: game_info_ui = found_info[0]
		game_info_ui.hp_bar.update_hp(hp, max_hp)
		game_info_ui.stamina_bar.update_stamina(stamina, max_stamina)
		
	if game_info_ui:
		game_info_ui.hp_bar.update_hp(hp, max_hp)
		if not coins_changed.is_connected(game_info_ui.update_coins_display):
			coins_changed.connect(game_info_ui.update_coins_display)
		game_info_ui.update_coins_display(coins)
		
		# Level Display
		if not xp_changed.is_connected(_on_xp_changed):
			xp_changed.connect(_on_xp_changed)

			# Manually trigger the first update to sync UI on start
		_on_xp_changed(foraging_xp, fishing_xp)

		if game_info_ui.has_method("update_item_display"):
			inventory.active_item_changed.connect(game_info_ui.update_item_display)
			inventory.active_item_changed.emit(null)
			
	inventory.equip_requested.connect(_on_inventory_equip_requested)
	
	coins_changed.emit(coins)
	xp_changed.emit(foraging_xp, fishing_xp)
	var head_detector = $Head/Camera3D/HeadDetector
	head_detector.area_entered.connect(_on_head_detector_area_entered)
	head_detector.area_exited.connect(_on_head_detector_area_exited)
	water_overlay.visible = false
	standard_overlay.visible = true
	crosshair.visible = true

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_settings_open:
			toggle_settings(false)
			toggle_inventory(false)
		elif is_menu_open:
			toggle_inventory(false)
		elif is_map_open:
			map_ui.visible = false
			crosshair.visible = !crosshair.visible
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			toggle_settings(!is_settings_open)
		return

	if event.is_action_pressed("inventory"):
		if not is_settings_open:
			toggle_inventory(!is_menu_open)
	
	if event.is_action_pressed("drop_item") and not is_menu_open:
		inventory.drop_current_item()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_menu_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("interact"):
		if not is_settings_open and not is_map_open and not is_menu_open:
			try_interact()
			try_interact_map()
		elif is_menu_open:
			toggle_inventory(false)

	if current_tool and not is_menu_open:
		# 1. Check for Primary Action (Digging, Using, etc.)
		if event.is_action_pressed("fire_primary"):
			# Get the item data currently held in the inventory
			var active_item = inventory.get_active_item() 
			if active_item and active_item.action_data:
				# This triggers the Shovel's DigActionData
					active_item.action_data.execute_action(self)
			elif current_tool.has_method("primary_action"):
				# Fallback for old tools that don't use ActionData
				current_tool.primary_action()
	
		# 2. Check for Secondary Action
		if event.is_action_pressed("fire_secondary") and current_tool.has_method("secondary_action"):
			current_tool.secondary_action(true)
		elif event.is_action_released("fire_secondary") and current_tool.has_method("secondary_action"):
			current_tool.secondary_action(false)

	if not is_menu_open:
		var is_fishing = current_tool and current_tool.has_method("is_fishing") and current_tool.is_fishing
		if event is InputEventMouseButton and event.is_pressed():
			if event.button_index == MOUSE_BUTTON_WHEEL_UP:
				inventory.change_active_slot(-1, is_fishing)
			elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				inventory.change_active_slot(1, is_fishing)
		for i in range(1, 10):
			if event.is_action_pressed("hotkey_" + str(i)):
				inventory.select_slot(i - 1, is_fishing)

func toggle_settings(open: bool):
	is_settings_open = open
	is_locked = open
	camera_controller.is_enabled = !open
	crosshair.visible = !crosshair.visible
	if settings_controller: settings_controller.visible = open
	
	if open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		interact_ray.enabled = false
		interact_ray_map.enabled = false
		if is_on_floor():
			velocity.x = 0
			velocity.z = 0 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		interact_ray.enabled = true
		interact_ray_map.enabled = true

# --- INVENTORY & EQUIPPING ---
func toggle_inventory(open: bool):
	is_menu_open = open
	is_locked = open
	camera_controller.is_enabled = !open
	crosshair.visible = !open
	
	if inventory_controller: inventory_controller.visible = open
	if hotbar_controller: hotbar_controller.visible = true 
	
	if external_inventory_node and not open:
		external_inventory_node.visible = false
		if external_inventory_node.current_inventory:
			var container = external_inventory_node.current_inventory
			if container.has_method("close_inventory"):
				container.close_inventory(self)
			external_inventory_node.current_inventory = null
	
	if open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		interact_ray.enabled = false
		interact_ray_map.enabled = false
		if is_on_floor():
			velocity.x = 0
			velocity.z = 0 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		interact_ray.enabled = true
		interact_ray_map.enabled = true

func open_external_inventory(container):
	if external_inventory_node and external_inventory_node.has_method("open_container"):
		external_inventory_node.open_container(container)
		toggle_inventory(true)
		

func _on_inventory_equip_requested(item_data: ItemData):
	# 1. Clean up old tool
	if current_tool and current_tool.has_method("unequip"):
		current_tool.unequip()
	current_tool = null
	
	for child in hand_socket.get_children():
		child.queue_free()
		
	# 2. Handle Case: Unequipping everything
	if not item_data or not item_data.equippable_scene:
		if anim_tree:
			# Slide back to "Idle/Walk" (Empty hands)
			var tween = create_tween()
			tween.tween_property(anim_tree, "parameters/Blend2/blend_amount", 0.0, 0.2)
		
		inventory.active_item_changed.emit(null)
		return

	# 3. Handle Case: Equipping an item
	var new_tool = item_data.equippable_scene.instantiate()
	hand_socket.add_child(new_tool)
	current_tool = new_tool
	
	if anim_tree:
		var tween = create_tween()
		tween.tween_property(anim_tree, "parameters/Blend2/blend_amount", 1.0, 0.2)
	
	if current_tool.has_method("setup"): 
		current_tool.setup(self)
	if current_tool.has_method("set_item_data"):
		current_tool.set_item_data(item_data)
		
	inventory.active_item_changed.emit(item_data)

# --- PHYSICS, INTERACTION, & WATER DETECTION REMAIN UNCHANGED ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor(): 
		velocity += (get_gravity() * gravity_multiplier) * delta

func _physics_process(delta: float) -> void:
	if is_menu_open or is_locked: 
		apply_gravity(delta)
		move_and_slide()
		return
		
	if state_machine.current_state and state_machine.current_state.name != "Run":
		if stamina < max_stamina:
			stamina += stamina_regen_rate * delta
	
	_handle_all_highlighting()
	state_machine.process_physics(delta)

func handle_stamina(delta: float) -> void:
	# 1. Check if the player is trying to sprint (Shift key) and is actually moving
	var is_moving = velocity.length() > 0.1
	var wants_to_sprint = Input.is_action_pressed("sprint") # Ensure "sprint" is in Input Map
	
	if wants_to_sprint and is_moving and stamina > 0:
		is_sprinting = true
		stamina -= stamina_drain_rate * delta
		speed_multiplier = sprint_speed / base_speed # Boost speed
	else:
		is_sprinting = false
		speed_multiplier = 1.0 # Return to normal speed
		
		# 2. Regenerate stamina if not sprinting
		if stamina < max_stamina:
			stamina += stamina_regen_rate * delta
	
	# 3. Clamp stamina so it doesn't go below 0 or above max
	stamina = clamp(stamina, 0, max_stamina)
	
	# 4. Update the UI (if your UI has a stamina bar)
	if game_info_ui and game_info_ui.has_method("update_stamina"):
		game_info_ui.update_stamina(stamina, max_stamina)

func _handle_all_highlighting():
	var target = null
	
	# 1. Check the standard ray first
	if interact_ray.is_colliding():
		target = interact_ray.get_collider()
	# 2. If the first hit nothing, check the map ray
	elif interact_ray_map.is_colliding():
		target = interact_ray_map.get_collider()
	
	# 3. Process the found target
	if target:
		var focus_target = null
		if target.has_method("focus"):
			focus_target = target
		elif target.get_parent() and target.get_parent().has_method("focus"):
			focus_target = target.get_parent()
		
		if focus_target:
			if last_focused_target != focus_target:
				_clear_highlight() # Clear the old one before focusing new
				focus_target.focus()
				last_focused_target = focus_target
			return # Exit early, we found something!
			
	# 4. If we reached here, neither ray found a valid focus target
	_clear_highlight()

func _clear_highlight():
	if last_focused_target:
		if is_instance_valid(last_focused_target):
			last_focused_target.unfocused()
		last_focused_target = null
		
func try_interact():
	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target.has_method("interact"):
			_clear_highlight()
			target.interact(self)
		elif target.get_parent().has_method("interact"):
			_clear_highlight()
			target.get_parent().interact(self)
			
func try_interact_map():
	if interact_ray_map.is_colliding():
		var target = interact_ray_map.get_collider()
		if target.has_method("interact"):
			_clear_highlight()
			target.interact(self)
		elif target.get_parent().has_method("interact"):
			_clear_highlight()
			target.get_parent().interact(self)

func _on_head_detector_area_entered(area):
	if area.is_in_group("water"):
		water_overlay.visible = true
		standard_overlay.visible = false
		gravity_multiplier = 0.2
		speed_multiplier = 0.6 
		velocity.y *= 0.2

func _on_head_detector_area_exited(area):
	if area.is_in_group("water"):
		water_overlay.visible = false
		standard_overlay.visible = true
		gravity_multiplier = 1.0
		speed_multiplier = 1.0

func add_to_inventory(item: ItemData):
	inventory.add_to_inventory(item)
	
func update_xp(xp_type: String, xp_value: float) -> void:
	match xp_type.to_lower():
		"foraging":
			# This triggers the setter, which emits the signal, 
			# which triggers the level calculation in _ready.
			foraging_xp += xp_value
			
		"fishing":
			fishing_xp += xp_value
			
		_:
			push_warning("Attempted to update unknown XP type: ", xp_type)

func handle_global_swap(from_id: int, to_id: int, new_data = null):
	# If we passed in new_data, it means we are BUYING/SPAWNING an item
	if from_id == -1 and new_data != null:
		# Check if your inventory component has a direct 'set' method
		# or access the array directly if it's in this script
		inventory.set_item_at_index(to_id, new_data)
		return

	# Otherwise, do your normal swapping logic
	inventory.handle_global_swap(from_id, to_id)

func attach_lure_to_rod(lure_id: int, rod_id: int):
	inventory.attach_lure_to_rod(lure_id, rod_id)

func remove_lure_from_rod(rod_slot_id: int):
	inventory.remove_lure_from_rod(rod_slot_id)
	
func get_item_at_index(id: int):
	return inventory.get_item_at_index(id)
	
var look_rotation: Vector2:
	get: return camera_controller.look_rotation
	set(value): camera_controller.look_rotation = value

var is_look_limited: bool:
	get: return camera_controller.is_look_limited
	set(value): camera_controller.is_look_limited = value

var look_limit_center: Vector2:
	get: return camera_controller.look_limit_center
	set(value): camera_controller.look_limit_center = value
	
func _on_xp_changed(new_foraging_xp: float, new_fishing_xp: float) -> void:
	var new_foraging_lvl = Math.calculate_xp_level(new_foraging_xp)
	var new_fishing_lvl = Math.calculate_xp_level(new_fishing_xp)
	
	if new_foraging_lvl != foraging_lvl:
		foraging_lvl = new_foraging_lvl
		double_forage_chance = .05 * foraging_lvl
		strength += 1
	if new_fishing_lvl != fishing_lvl:
		fishing_lvl = new_fishing_lvl
		strength += 1


	# Always update the UI display
	if game_info_ui:
		game_info_ui.update_levels_display(foraging_lvl, fishing_lvl)
		

func take_damage(amount: int) -> void:
	hp -= amount
	hp = clamp(hp, 0, max_hp)
	
	# Update the UI
	if game_info_ui and game_info_ui.hp_bar:
		game_info_ui.hp_bar.update_hp(hp, max_hp)
		
	print("Player took damage! Current HP: ", hp)
	
	if hp <= 0:
		die()

func die() -> void:
	print("Player has died!")
	# For now, let's just reload the current scene
	get_tree().reload_current_scene()
