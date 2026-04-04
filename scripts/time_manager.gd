extends Node3D

signal day_started(day_count)
var sun_color = preload("res://shaders/sun_colors.tres")
var sun_intensity = preload("res://shaders/sun_intensity.tres")
@export var day_length_minutes: float = 15.0

var sun: DirectionalLight3D # Remove the @onready path here
var current_day: int = 1
var day_triggered: bool = false
var time_of_day: float = 7.0 
var time_rate: float

func _ready() -> void:
	time_rate = 24.0 / (day_length_minutes * 60.0)
	# Find the sun immediately when the game starts
	find_sun()

func find_sun():
	var sun_nodes = get_tree().get_nodes_in_group("sun")
	
	if sun_nodes.size() > 0:
		sun = sun_nodes[0] as DirectionalLight3D
	else:
		sun = null

func _process(delta: float) -> void:
	if not is_instance_valid(sun):
		find_sun()
		return # Skip this frame if sun is still missing
	
	time_of_day += time_rate * delta
	
	if time_of_day >= 24.0:
		time_of_day -= 24.0
		current_day += 1
		day_triggered = false
		
	if not day_triggered and time_of_day >= 7.0:
		day_triggered = true
		day_started.emit(current_day)
	
	update_day_night_cycle()

func update_day_night_cycle() -> void:
	# Double check sun exists before touching its properties
	if sun == null: 
		return
		
	var normalized_time = time_of_day / 24.0
	var sun_angle = (normalized_time * 360.0) - 90.0
	sun.rotation_degrees.x = -sun_angle
	
	if sun_color:
		sun.light_color = sun_color.sample(normalized_time)
	if sun_intensity:
		sun.light_energy = sun_intensity.sample(normalized_time)
