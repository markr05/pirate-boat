extends CharacterBody3D

signal coins_changed(coins_amount)
signal inventory_closed

# --- REFERENCES ---
@onready var camera_controller: CameraController = $Head # CHANGED: Now references the new script
@onready var camera: Camera3D = $Head/Camera3D
@onready var hand_position: Node3D = $Head/Camera3D/HandPosition
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D
@onready var collider: CollisionShape3D = $Collider
@onready var anim_player = $player/AnimationPlayer
@onready var state_machine: PlayerStateMachine = $StateMachine
@onready var inventory: InventoryComponent = $InventoryComponent

# --- UI REFERENCES ---
@onready var inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI
@onready var hotbar_controller: Node = %InventoryController/CanvasLayer/HotbarUI
@export var game_info_ui: Control = null
@onready var external_inventory_node = $CanvasLayer/ExternalInventoryUI
@onready var water_overlay = $CanvasLayer/GameInfo/WaterVision
@onready var standard_overlay = $CanvasLayer/GameInfo/StandardVision

# --- SETTINGS ---
@export_group("Movement")
@export var base_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var jump_velocity: float = 4.5
var gravity_multiplier: float = 1.0
var speed_multiplier: float = 1.0

# --- STATE ---
var seat_target: Node3D = null 
var is_menu_open: bool = false
var is_locked: bool = false 

# Tool
var current_tool: Node3D = null

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
		
	if game_info_ui:
		if not coins_changed.is_connected(game_info_ui.update_coins_display):
			coins_changed.connect(game_info_ui.update_coins_display)
		game_info_ui.update_coins_display(coins)
	
		if game_info_ui.has_method("update_item_display"):
			inventory.active_item_changed.connect(game_info_ui.update_item_display)
			inventory.active_item_changed.emit(null)
			
	inventory.equip_requested.connect(_on_inventory_equip_requested)
	
	coins_changed.emit(coins)
	var head_detector = $Head/Camera3D/HeadDetector
	head_detector.area_entered.connect(_on_head_detector_area_entered)
	head_detector.area_exited.connect(_on_head_detector_area_exited)
	water_overlay.visible = false
	standard_overlay.visible = true

# --- INPUT ---
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_menu_open:
			toggle_inventory(false)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		return

	if event.is_action_pressed("inventory"):
		toggle_inventory(!is_menu_open)
	
	if event.is_action_pressed("drop_item") and not is_menu_open:
		inventory.drop_current_item()

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not is_menu_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event.is_action_pressed("interact"):
		try_interact()

	if current_tool and not is_menu_open:
		if event.is_action_pressed("fire_primary") and current_tool.has_method("primary_action"):
			current_tool.primary_action()
		
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

# --- INVENTORY & EQUIPPING ---
func toggle_inventory(open: bool):
	is_menu_open = open
	is_locked = open
	camera_controller.is_enabled = !open
	
	if inventory_controller: inventory_controller.visible = open
	if hotbar_controller: hotbar_controller.visible = true 
	
	if external_inventory_node and not open:
		external_inventory_node.visible = false
		var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
		
		if external_ui and external_ui.current_inventory:
			if external_ui.current_inventory.has_method("on_player_closed_npc"):
				external_ui.current_inventory.on_player_closed_npc(self)
			external_ui.current_inventory = null
	
	if open:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		interact_ray.enabled = false
		if is_on_floor():
			velocity.x = 0
			velocity.z = 0 
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		interact_ray.enabled = true

func open_external_inventory(chest):
	if external_inventory_node and external_inventory_node.has_method("open_container"):
		external_inventory_node.open_container(chest)
		toggle_inventory(true)

func _on_inventory_equip_requested(item_data: ItemData):
	if current_tool and current_tool.has_method("unequip"):
		current_tool.unequip()
	current_tool = null
	for child in hand_position.get_children():
		child.queue_free()
		
	if item_data and item_data.equippable_scene:
		var new_tool = item_data.equippable_scene.instantiate()
		hand_position.add_child(new_tool)
		current_tool = new_tool
		
		if current_tool.has_method("setup"): 
			current_tool.setup(self)
		if current_tool.has_method("set_item_data"):
			current_tool.set_item_data(item_data)

# --- PHYSICS ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor(): 
		velocity += (get_gravity() * gravity_multiplier) * delta

func _physics_process(delta: float) -> void:
	if seat_target:
		global_transform = seat_target.global_transform
		if anim_player.current_animation != "Pirate_Sit":
			anim_player.play("Pirate_Sit", 0.2)
		return 
		
	if is_menu_open or is_locked: 
		apply_gravity(delta)
		move_and_slide()
		return
	
	state_machine.process_physics(delta)

# --- INTERACTION ---
func try_interact():
	if seat_target:
		exit_boat_mode()
		return

	if interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		if target.has_method("interact"):
			target.interact(self)
		elif target.get_parent().has_method("interact"):
			target.get_parent().interact(self)

# --- BOAT MODES ---
func enter_boat_mode(target_seat: Node3D):
	inventory.select_slot(-1) 
	seat_target = target_seat
	is_locked = true
	collider.disabled = true
	global_transform = seat_target.global_transform
	camera_controller.enter_seat() # NEW: Tell camera we are seated

func exit_boat_mode():
	seat_target = null
	is_locked = false
	collider.disabled = false
	
	var boat_yaw = global_rotation.y
	global_position.y += 1.5
	camera_controller.exit_seat(boat_yaw) # NEW: Tell camera we stood up

# --- WATER DETECTION ---
func _on_head_detector_area_entered(area):
	if area.is_in_group("water"):
		water_overlay.visible = true
		standard_overlay.visible = false
		water_overlay.material.set_shader_parameter("blue_tint", Color(0.0, 0.4, 0.8, 0.4))
		gravity_multiplier = 0.2
		speed_multiplier = 0.6 
		velocity.y *= 0.2

func _on_head_detector_area_exited(area):
	if area.is_in_group("water"):
		water_overlay.visible = false
		standard_overlay.visible = true
		water_overlay.material.set_shader_parameter("blue_tint", Color(0.0, 0.4, 0.8, 0.0))
		gravity_multiplier = 1.0
		speed_multiplier = 1.0

# --- INVENTORY HELPERS ---
func add_to_inventory(item: ItemData):
	inventory.add_to_inventory(item)

func handle_global_swap(from_id: int, to_id: int):
	inventory.handle_global_swap(from_id, to_id)

func attach_lure_to_rod(lure_id: int, rod_id: int):
	inventory.attach_lure_to_rod(lure_id, rod_id)

func remove_lure_from_rod(rod_slot_id: int):
	inventory.remove_lure_from_rod(rod_slot_id)
	
func get_item_at_index(id: int):
	return inventory.get_item_at_index(id)
	
# --- CAMERA HELPERS ---
var look_rotation: Vector2:
	get: return camera_controller.look_rotation
	set(value): camera_controller.look_rotation = value

var is_look_limited: bool:
	get: return camera_controller.is_look_limited
	set(value): camera_controller.is_look_limited = value

var look_limit_center: Vector2:
	get: return camera_controller.look_limit_center
	set(value): camera_controller.look_limit_center = value
