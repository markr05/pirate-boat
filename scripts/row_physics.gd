extends RigidBody3D
class_name RowBoat

# --- Settings ---
@export var float_force: float = 60.0
@export var water_drag: float = 3.0
@export var wave_influence: float = 0.6
@export var water_height_offset: float = 10.0
@export var oar_impulse: float = 30.0
@export var oar_side_offset: float = 1.0
@export var stroke_duration: float = 2.0  
@export var turn_multiplier: float = 0.4 

var left_oar_force: float = 0.0
var right_oar_force: float = 0.0

# NEW: Keep track of our tweens so they don't fight
var left_tween: Tween
var right_tween: Tween

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

# --- Public Rowing Methods (Called by Player State) ---
func row_left():
	sleeping = false # CRITICAL: Wake the physics body up!
	_apply_sustained_push("left")

func row_right():
	sleeping = false # CRITICAL: Wake the physics body up!
	_apply_sustained_push("right")

func _apply_sustained_push(side: String):
	if side == "left":
		# Kill the old tween if we are starting a new stroke early
		if left_tween:
			left_tween.kill() 
			
		left_tween = create_tween()
		left_oar_force = 0.0
		left_tween.tween_property(self, "left_oar_force", 1.0, 0.2) 
		left_tween.tween_property(self, "left_oar_force", 0.0, stroke_duration - 0.2) 
		
	else:
		# Kill the old tween if we are starting a new stroke early
		if right_tween:
			right_tween.kill()
			
		right_tween = create_tween()
		right_oar_force = 0.0
		right_tween.tween_property(self, "right_oar_force", 1.0, 0.2)
		right_tween.tween_property(self, "right_oar_force", 0.0, stroke_duration - 0.2)

# --- Physics ---
func _physics_process(delta: float) -> void:
	_apply_buoyancy()
	
	var forward = -global_transform.basis.z
	var total_oar_power = left_oar_force + right_oar_force
	
	if total_oar_power > 0:
		var forward_push = forward * (oar_impulse * total_oar_power * mass * (1.0 - turn_multiplier))
		apply_central_force(forward_push)
		
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
			var drag_vector = -linear_velocity * water_drag * mass
			apply_force(drag_vector * 0.5, probe.global_position - global_position)
