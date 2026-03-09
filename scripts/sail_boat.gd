extends RigidBody3D
class_name SailBoat

# --- Settings ---
@export_group("Buoyancy")
@export var float_force: float = 60.0
@export var water_drag: float = 3.0
@export var wave_influence: float = 0.6
@export var water_height_offset: float = 10.0

@export_group("Sailing")
@export var sail_thrust: float = 40.0 # How hard the wind pushes
@export var rudder_power: float = 8.0 # How fast you turn
@export var max_speed: float = 12.0

# --- State ---
var is_sail_dropped: bool = false
var steering_input: float = 0.0

# --- References ---
@onready var probes = [$Probe1, $Probe2, $Probe3, $Probe4]
@export var seat_node: Node3D

func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0)
	
	if seat_node == null:
		seat_node = get_node_or_null("SeatMarker")

# --- Interaction Logic ---
func interact(player_node):
	if player_node.state_machine.current_state.name == "Boat":
		pass 
	else:
		player_node.current_boat = self
		player_node.state_machine.transition_to("Boat")

# --- Public Methods for the Player ---
func set_steering(amount: float):
	# -1.0 is right, 1.0 is left, 0.0 is straight
	steering_input = amount

func toggle_sail():
	is_sail_dropped = !is_sail_dropped
	print("Sail dropped: ", is_sail_dropped)
	# Optional: Play a visual animation here to lower/raise the sail mesh!

# --- Physics ---
func _physics_process(delta: float) -> void:
	_apply_buoyancy()
	
	var forward_dir = -global_transform.basis.z
	var current_speed = linear_velocity.length()
	
	# 1. THE WIND (Forward Thrust)
	if is_sail_dropped and current_speed < max_speed:
		var push_force = forward_dir * (sail_thrust * mass)
		apply_central_force(push_force)
		
	# 2. THE RUDDER (Turning)
	if steering_input != 0.0:
		# A rudder only works if the boat is moving forward! 
		# We multiply the turn force by our current speed so you can't spin while standing still.
		var flow_over_rudder = clamp(current_speed / 2.0, 0.0, 1.0) 
		var turn_torque = global_transform.basis.y * (steering_input * rudder_power * flow_over_rudder * mass)
		
		# Apply the torque to twist the boat
		apply_torque(turn_torque)

func _apply_buoyancy():
	var sync_time = Time.get_ticks_msec() / 1000.0
	var force_per = float_force / probes.size()
	for probe in probes:
		var depth = ((sin(sync_time + probe.global_position.x) * 0.5 * wave_influence) + water_height_offset) - probe.global_position.y
		if depth > 0:
			apply_force(Vector3.UP * depth * force_per * mass, probe.global_position - global_position)
			
			# Water drag to slow the boat down naturally
			var drag_vector = -linear_velocity * water_drag * mass
			apply_force(drag_vector * 0.5, probe.global_position - global_position)
