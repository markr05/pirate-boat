extends EquippableItem

# Drag the child node containing FishingManager.gd here in inspector
@export var fishing_manager: Node 

@onready var bobber: CharacterBody3D = %Bobber
@onready var fishing_line_starter_marker: Marker3D = %FishingLineStarterMarker
@onready var bobber_start_marker: Marker3D = %BobberStartMarker
@onready var fishing_line: MeshInstance3D = %FishingLine

# --- SETTINGS ---
const THROW_FORCE = 10.0
const THROW_ARC = 3.0
const REEL_IN_SPEED = 2.0
const REEL_OUT_SPEED = 2.0
const MIN_LENGTH = 1.0
const MAX_LENGTH = 100.0
const ROPE_STIFFNESS = 40.0
const CATCH_DISTANCE = 1.5 

# --- STATE ---
var is_fishing: bool = false
var in_water: bool = false
var current_rope_length: float = 1.0
var cast_timer: float = 0.0

func setup(player):
	super.setup(player)
	bobber.set_as_top_level(true)
	if fishing_line: fishing_line.set_as_top_level(true)
	bobber.set_physics_process(true)
	if fishing_line: fishing_line.hide()
	
	# Connect Signals
	if fishing_manager and not fishing_manager.is_connected("fish_bit", _on_fish_bite_received):
		fishing_manager.fish_bit.connect(_on_fish_bite_received)
	
	if not bobber.is_connected("entered_water", _on_bobber_entered_water):
		bobber.entered_water.connect(_on_bobber_entered_water)

func _on_bobber_entered_water():
	if is_fishing and not in_water:
		in_water = true
		if fishing_manager: fishing_manager.start_waiting()
		
		# Set rope length to current distance so it doesn't snap back immediately
		var current_dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
		if current_rope_length < current_dist:
			current_rope_length = current_dist

func primary_action():
	if not is_fishing:
		start_fishing()

func _physics_process(delta: float) -> void:
	if is_fishing:
		if cast_timer > 0: cast_timer -= delta
		_refresh_line()
		_handle_inputs(delta)
		_handle_physics(delta)
	else:
		# Snap to rod
		bobber.global_position = bobber_start_marker.global_position
		bobber.velocity = Vector3.ZERO
		if fishing_line: fishing_line.hide()

func _handle_inputs(delta: float):
	if Input.is_action_pressed("fire_primary"):
		current_rope_length += REEL_OUT_SPEED * delta
	
	if Input.is_action_pressed("fire_secondary"):
		current_rope_length -= REEL_IN_SPEED * delta
		var dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
		if current_rope_length > dist + 1.0:
			current_rope_length = dist # Remove slack
	
	current_rope_length = clamp(current_rope_length, MIN_LENGTH, MAX_LENGTH)

func _handle_physics(delta: float):
	var rod_tip = fishing_line_starter_marker.global_position
	var dist = bobber.global_position.distance_to(rod_tip)
	
	# Catch/Retrieve Logic
	if cast_timer <= 0.0 and dist < CATCH_DISTANCE:
		stop_fishing()
		return 

	var is_underwater = bobber.get("is_floating") or in_water

	# Gravity / Buoyancy Drag
	if not bobber.is_on_floor() and not is_underwater:
		bobber.velocity += player_ref.get_gravity() * delta
	elif is_underwater:
		bobber.velocity *= 0.9 # Water resistance

	# Rope Physics
	var is_reeling = Input.is_action_pressed("fire_secondary")
	if dist > current_rope_length:
		var direction_to_rod = (rod_tip - bobber.global_position).normalized()
		var stretch = dist - current_rope_length
		
		# Separate Pull vectors
		var horizontal_pull = Vector3(direction_to_rod.x, 0, direction_to_rod.z)
		var vertical_pull = Vector3(0, direction_to_rod.y, 0)
		
		# Apply Pull
		bobber.velocity += horizontal_pull * (stretch * ROPE_STIFFNESS) * delta
		bobber.velocity += vertical_pull * (stretch * ROPE_STIFFNESS * 0.4) * delta
		
		# Damping
		bobber.velocity *= 0.95
		
		# Stop bouncing away
		var vel_away = bobber.velocity.dot(-direction_to_rod)
		if vel_away > 0:
			bobber.velocity += direction_to_rod * vel_away
			
		# Reeling force
		var force_multiplier = 4.0 if is_reeling else 1.0
		bobber.velocity += direction_to_rod * (stretch * ROPE_STIFFNESS * force_multiplier) * delta

	bobber.move_and_slide()

func start_fishing():
	is_fishing = true
	in_water = false
	cast_timer = 1.0 
	
	# Lock player view and movement
	player_ref.look_limit_center = player_ref.look_rotation
	player_ref.is_look_limited = true
	player_ref.is_locked = true 
	
	if bobber.has_method("reset_bobber"): bobber.reset_bobber()
	if fishing_line: fishing_line.show()
	
	current_rope_length = 10.0 
	bobber.global_position = fishing_line_starter_marker.global_position
	
	var camera = player_ref.camera
	var throw_dir = -camera.global_transform.basis.z 
	
	bobber.velocity = throw_dir * THROW_FORCE
	bobber.velocity.y += THROW_ARC

func _on_fish_bite_received():
	if is_fishing and bobber:
		print("Rod: I felt a tug!")
		bobber.velocity.y -= 4.0 

func stop_fishing():
	is_fishing = false
	in_water = false
	if fishing_manager: fishing_manager.reset()

	player_ref.is_look_limited = false
	player_ref.is_locked = false
	
	if fishing_line: fishing_line.hide()

func _refresh_line():
	if not fishing_line: return
	var start = fishing_line_starter_marker.global_position
	var end = bobber.global_position
	var dist = start.distance_to(end)
	
	if dist < 0.1:
		fishing_line.hide()
		return
	
	fishing_line.show()
	fishing_line.global_position = (start + end) / 2.0
	
	if abs(start.x - end.x) < 0.01 and abs(start.z - end.z) < 0.01:
		fishing_line.look_at(end, Vector3.RIGHT)
	else:
		fishing_line.look_at(end, Vector3.UP)
	
	fishing_line.rotation_degrees.x -= 90 
	
	if fishing_line.mesh is CylinderMesh or fishing_line.mesh is CapsuleMesh:
		fishing_line.mesh.height = dist
