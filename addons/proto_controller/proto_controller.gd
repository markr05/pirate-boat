# ProtoController v2.0 (Merged: Boat, Raycast, & Fishing Support)
extends CharacterBody3D

signal inventory_changed(new_inventory)

# --- INVENTORY SETTINGS ---
@export var inventory: Array[ItemData] = []
@onready var hand_position: Node3D = $Head/Camera3D/HandPosition
# Assign your UI Control node here in the Inspector
@export var hotbar_ui: Control = null 

# --- REFERENCES ---
@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var collider: CollisionShape3D = $Collider
# MAKE SURE YOU ADD A RayCast3D NODE AS A CHILD OF Camera3D!
@onready var interact_ray: RayCast3D = $Head/Camera3D/RayCast3D

# --- MOVEMENT SETTINGS ---
@export var base_speed: float = 7.0
@export var sprint_speed: float = 10.0
@export var look_speed: float = 0.002
@export var jump_velocity: float = 4.5

# --- STATE ---
var mouse_captured: bool = false
var look_rotation: Vector2
var seat_target: Node3D = null 
var is_menu_open: bool = false

# Locking states for Fishing/Boats
@export var is_locked: bool = false 
var current_tool = null
var look_limit_center: Vector2 = Vector2.ZERO
var is_look_limited: bool = false

var current_slot = 0
var inventory_slots: Array = [] 
const MAX_SLOTS = 9

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	mouse_captured = true
	look_rotation.y = rotation.y
	look_rotation.x = head.rotation.x
	
	# Initial Inventory Update
	# Initialize empty slots
	inventory_slots.resize(MAX_SLOTS)
	inventory_slots.fill(null)
	
	# Try to find hotbar if missing
	if hotbar_ui == null:
		var found = get_tree().get_nodes_in_group("hotbar")
		if found.size() > 0: hotbar_ui = found[0]

	# Update UI
	inventory_changed.emit(inventory_slots)
	if hotbar_ui: hotbar_ui.update_hotbar_ui(inventory_slots)

# --- INPUT LOGIC ---
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		if not is_menu_open:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			mouse_captured = true
	if Input.is_key_pressed(KEY_ESCAPE):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		mouse_captured = false
	
	# Mouse Look
	if mouse_captured and event is InputEventMouseMotion and not is_menu_open:
		look_rotation.x -= event.relative.y * look_speed
		look_rotation.y -= event.relative.x * look_speed
		
		look_rotation.x = clamp(look_rotation.x, deg_to_rad(-85), deg_to_rad(85))
		
		# 1. Fishing Limitation (Restricts view when rod is cast)
		if is_look_limited:
			look_rotation.y = clamp(look_rotation.y, look_limit_center.y - deg_to_rad(45), look_limit_center.y + deg_to_rad(45))
			look_rotation.x = clamp(look_rotation.x, look_limit_center.x - deg_to_rad(45), look_limit_center.x + deg_to_rad(45))
			
		# 2. Boat Limitation
		if seat_target: 
			look_rotation.y = clamp(look_rotation.y, deg_to_rad(-100), deg_to_rad(100))
			head.rotation.y = look_rotation.y
			head.rotation.x = look_rotation.x
		
		# 3. Normal Walk Mode
		else: 
			transform.basis = Basis()
			rotate_y(look_rotation.y)
			head.transform.basis = Basis()
			head.rotate_x(look_rotation.x)
			head.rotation.y = 0
	
	# NEW: Raycast Interaction
	if Input.is_action_just_pressed("interact"):
		try_interact()

	# Tool Use
	if current_tool and not is_menu_open:
		if Input.is_action_just_pressed("fire_primary"):
			if current_tool.has_method("primary_action"): current_tool.primary_action()
		
		if Input.is_action_pressed("fire_secondary"):
			if current_tool.has_method("secondary_action"): current_tool.secondary_action(true)
		elif Input.is_action_just_released("fire_secondary"):
			if current_tool.has_method("secondary_action"): current_tool.secondary_action(false)

	# Hotkey Selection (1-9)
	for i in range(1, 10):
		if Input.is_action_just_pressed("hotkey_" + str(i)):
			select_slot(i - 1)

# --- PHYSICS ---
func _physics_process(delta: float) -> void:
	
	# Menu or Locked State (Fishing/Cutscenes)
	if is_menu_open or is_locked: 
		velocity.x = 0
		velocity.z = 0
		if not is_on_floor(): velocity += get_gravity() * delta
		move_and_slide()
		return
		
	# Boat State
	if seat_target:
		global_position = seat_target.global_position
		global_rotation.y = seat_target.global_rotation.y
		return
	
	# Standard Movement
	if not is_on_floor(): velocity += get_gravity() * delta
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
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

# --- INTERACTION SYSTEM ---
func try_interact():
	# If in boat, interact to get out
	if seat_target:
		exit_boat_mode()
		return

	# If looking at something interactable
	if interact_ray and interact_ray.is_colliding():
		var target = interact_ray.get_collider()
		# Check the object itself
		if target.has_method("interact"):
			target.interact(self)
		# Check parent (common if colliding with a child mesh)
		elif target.get_parent().has_method("interact"):
			target.get_parent().interact(self)

# --- INVENTORY SYSTEM ---

func add_to_inventory(item: ItemData):
	# 1. CHECK FOR STACKING (If item is stackable, look for existing pile)
	if item.stackable:
		for i in range(inventory_slots.size()):
			var slot = inventory_slots[i]
			if slot != null and slot["data"] == item:
				if slot["quantity"] < item.max_stack_size:
					slot["quantity"] += 1
					print("Added to stack: " + item.name + " x" + str(slot["quantity"]))
					_refresh_inventory()
					return # We found a stack, job done!

	# 2. FIND EMPTY SLOT (If no stack found or item not stackable)
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			inventory_slots[i] = { "data": item, "quantity": 1 }
			print("Added to new slot: " + item.name)
			_refresh_inventory()
			# If we filled the slot we are currently holding, equip it
			if i == current_slot:
				equip_item(item)
			return

	print("Inventory Full!")

func _refresh_inventory():
	inventory_changed.emit(inventory_slots)
	if hotbar_ui and hotbar_ui.has_method("update_hotbar_ui"):
		hotbar_ui.update_hotbar_ui(inventory_slots)

func select_slot(index: int):
	if current_tool and "is_fishing" in current_tool and current_tool.is_fishing:
		return
		
	current_slot = index
	if hotbar_ui: hotbar_ui.set_active_slot(index)
	
	# Check if the selected slot has an item
	if index < inventory_slots.size() and inventory_slots[index] != null:
		equip_item(inventory_slots[index]["data"])
	else:
		unequip_hand()

func equip_item(item_data: ItemData):
	unequip_hand()
	if item_data.equippable_scene:
		var new_item = item_data.equippable_scene.instantiate()
		hand_position.add_child(new_item)
		current_tool = new_item
		if new_item.has_method("setup"):
			new_item.setup(self)

func unequip_hand():
	if current_tool and current_tool.has_method("unequip"):
		current_tool.unequip()
	current_tool = null
	for child in hand_position.get_children():
		child.queue_free()

# --- BOAT FUNCTIONS ---
func enter_boat_mode(target_seat: Node3D):
	seat_target = target_seat
	is_locked = true
	velocity = Vector3.ZERO
	collider.disabled = true
	global_position = seat_target.global_position
	global_rotation.y = seat_target.global_rotation.y
	look_rotation = Vector2.ZERO
	head.rotation = Vector3.ZERO

func exit_boat_mode():
	seat_target = null
	is_locked = false
	collider.disabled = false
	var final_yaw = global_rotation.y + head.rotation.y
	global_position.y += 1.5
	global_rotation.y = final_yaw
	head.rotation.y = 0
	look_rotation.y = final_yaw
	look_rotation.x = head.rotation.x
