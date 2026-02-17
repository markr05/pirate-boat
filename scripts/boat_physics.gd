extends RigidBody3D

# --- Settings ---
@export var float_force: float = 60.0
@export var water_drag: float = 3.0
@export var wave_influence: float = 0.6
@export var water_height_offset: float = 0.0
@export var oar_impulse: float = 30.0
@export var oar_side_offset: float = 1.0

var left_oar_force: float = 0.0
var right_oar_force: float = 0.0
@export var stroke_duration: float = 2.0  # How long the push lasts

# --- References ---
@onready var probes = [$Probe1, $Probe2, $Probe3, $Probe4]
@export var seat_node: Node3D

var current_rower: Node3D = null # We store who is rowing

func _ready() -> void:
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, -1.0, 0)
	
	# Safety check for the seat
	if seat_node == null:
		seat_node = get_node_or_null("SeatMarker")

# --- Interaction Logic (Called by Player Raycast) ---
func interact(player_node):
	if current_rower:
		_eject_rower()
	else:
		_seat_rower(player_node)

func _seat_rower(player):
	current_rower = player
	if current_rower.has_method("enter_boat_mode"):
		# Pass the seat node to the player
		current_rower.enter_boat_mode(seat_node)

func _eject_rower():
	if current_rower.has_method("exit_boat_mode"):
		current_rower.exit_boat_mode()
	current_rower = null


func _handle_rowing() -> void:
	# 1. Detect Inputs
	if Input.is_action_just_pressed("fire_primary"):
		_apply_sustained_push("left")
	
	if Input.is_action_just_pressed("fire_secondary"):
		_apply_sustained_push("right")

func _apply_sustained_push(side: String):
	# Create a tween to ramp the force up and down
	var tween = create_tween()
	
	# Reset force and ramp it up quickly, then down slowly
	if side == "left":
		left_oar_force = 0.0
		tween.tween_property(self, "left_oar_force", 1.0, 0.2) # Ramp up (0.2s)
		tween.tween_property(self, "left_oar_force", 0.0, stroke_duration - 0.2) # Fade out
	else:
		right_oar_force = 0.0
		tween.tween_property(self, "right_oar_force", 1.0, 0.2)
		tween.tween_property(self, "right_oar_force", 0.0, stroke_duration - 0.2)

@export var turn_multiplier: float = 0.2 # 0.0 = perfectly straight, 1.0 = very spinny

func _physics_process(delta: float) -> void:
	_apply_buoyancy()
	
	if current_rower:
		_handle_rowing()
		
		var forward = -global_transform.basis.z
		
		# Calculate combined oar power (0.0 to 1.0)
		var total_oar_power = left_oar_force + right_oar_force
		
		if total_oar_power > 0:
			# --- 1. THE FORWARD PUSH (THROUGH THE CENTER) ---
			# This part of the force CANNOT turn the boat.
			var forward_push = forward * (oar_impulse * total_oar_power * mass * (1.0 - turn_multiplier))
			apply_central_force(forward_push)
			
			# --- 2. THE TURNING PUSH (FROM THE SIDES) ---
			# Apply individual oar forces at their offsets for the turning effect.
			if left_oar_force > 0:
				var oar_pos = -global_transform.basis.x * oar_side_offset
				var turn_force = forward * (oar_impulse * left_oar_force * mass * turn_multiplier)
				apply_force(turn_force, oar_pos)
				
			if right_oar_force > 0:
				var oar_pos = global_transform.basis.x * oar_side_offset
				var turn_force = forward * (oar_impulse * right_oar_force * mass * turn_multiplier)
				apply_force(turn_force, oar_pos)

func _apply_buoyancy():
	var sync_time = Time.get_ticks_msec() / 1000.0
	var force_per = float_force / probes.size()
	for probe in probes:
		var depth = ((sin(sync_time + probe.global_position.x) * 0.5 * wave_influence) + water_height_offset) - probe.global_position.y
		if depth > 0:
			apply_force(Vector3.UP * depth * force_per * mass, probe.global_position - global_position)
		
			# SLIGHTLY REDUCE ROTATIONAL DRAG:
			# We only apply a fraction of the drag to the side-to-side (rotational) movement
			var drag_vector = -linear_velocity * water_drag * mass
			apply_force(drag_vector * 0.5, probe.global_position - global_position)	
