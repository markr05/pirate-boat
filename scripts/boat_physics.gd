extends RigidBody3D

# --- Settings ---
@export var float_force: float = 60.0
@export var water_drag: float = 3.0
@export var wave_influence: float = 0.6
@export var water_height_offset: float = 0.0
@export var oar_impulse: float = 12.0
@export var oar_side_offset: float = 1.5

# --- References ---
@export var seat_marker_path: NodePath = "SeatMarker"
@export var interaction_area_path: NodePath = "InteractionArea"
@onready var probes = [$Probe1, $Probe2, $Probe3, $Probe4]
@onready var seat = get_node(seat_marker_path)
@onready var interaction_area = get_node(interaction_area_path)

var current_rower: Node3D = null # We store who is rowing

func _ready() -> void:
	# Ensure the seat is rotated correctly in the editor (Blue arrow points BACK)
	interaction_area.body_entered.connect(_on_player_entered)
	interaction_area.body_exited.connect(_on_player_exited)
	
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0)

# --- Interaction Logic ---
var potential_rower = null

func _on_player_entered(body: Node3D) -> void:
	if body.is_in_group("player"): potential_rower = body

func _on_player_exited(body: Node3D) -> void:
	if body == potential_rower: potential_rower = null

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		if current_rower:
			_eject_rower()
		elif potential_rower:
			_seat_rower(potential_rower)

func _seat_rower(player):
	current_rower = player
	
	# Tell the player to lock onto our Seat Node
	if current_rower.has_method("enter_boat_mode"):
		current_rower.enter_boat_mode(seat)

func _eject_rower():
	if current_rower.has_method("exit_boat_mode"):
		current_rower.exit_boat_mode()
	current_rower = null

# --- Physics & Rowing ---
func _physics_process(delta: float) -> void:
	_apply_buoyancy()
	
	# Only allow rowing if someone is sitting
	if current_rower:
		_handle_rowing()

@export var turn_influence: float = 0.3 # 0.0 is straight only, 1.0 is original spinny behavior

func _handle_rowing() -> void:
	var forward = -global_transform.basis.z 
	var total_force = forward * oar_impulse * mass
	
	# Split the force: 
	# Part 1: Pure forward force (applied to center of mass)
	var forward_component = total_force * (1.0 - turn_influence)
	
	# Part 2: Turning force (applied to the side oar position)
	var turn_component = total_force * turn_influence

	if Input.is_action_just_pressed("fire_primary"): # Left Oar
		var oar_pos = -global_transform.basis.x * oar_side_offset
		apply_central_impulse(forward_component) # Push boat forward
		apply_impulse(turn_component, Vector3(oar_pos.x, 0, oar_pos.z)) # Turn boat
	
	if Input.is_action_just_pressed("fire_secondary"): # Right Oar
		var oar_pos = global_transform.basis.x * oar_side_offset
		apply_central_impulse(forward_component) # Push boat forward
		apply_impulse(turn_component, Vector3(oar_pos.x, 0, oar_pos.z)) # Turn boat
func _apply_buoyancy():
	var sync_time = Time.get_ticks_msec() / 1000.0
	var force_per = float_force / probes.size()
	for probe in probes:
		var depth = ((sin(sync_time + probe.global_position.x) * 0.5 * wave_influence) + water_height_offset) - probe.global_position.y
		if depth > 0:
			apply_force(Vector3.UP * depth * force_per * mass, probe.global_position - global_position)
			apply_force(-linear_velocity * water_drag * mass, probe.global_position - global_position)
