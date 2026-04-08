extends Node3D

signal day_started(day_count)

# Sun Gradients
var sun_color = preload("res://shaders/sun_colors.tres")
var sun_intensity = preload("res://shaders/sun_intensity.tres")

# NEW: Sky Gradients (You need to create these!)
var sky_top_gradient = preload("res://shaders/sky_top_colors.tres")
var sky_horizon_gradient = preload("res://shaders/sky_horizon_colors.tres")

@export var day_length_minutes: float = 15.0

var sun: DirectionalLight3D 
var world_env: WorldEnvironment # NEW: Reference to your WorldEnvironment
var sky_mat: ProceduralSkyMaterial # NEW: Reference to the material we want to change

var current_day: int = 1
var day_triggered: bool = false
var time_of_day: float = 7.0 
var time_rate: float

func _ready() -> void:
	time_rate = 24.0 / (day_length_minutes * 60.0)
	find_sun()
	find_environment() # NEW: Find the sky

func find_sun():
	var sun_nodes = get_tree().get_nodes_in_group("sun")
	if sun_nodes.size() > 0:
		sun = sun_nodes[0] as DirectionalLight3D
	else:
		sun = null

# NEW: Find the WorldEnvironment and its Sky Material
func find_environment():
	var env_nodes = get_tree().get_nodes_in_group("environment")
	if env_nodes.size() > 0:
		world_env = env_nodes[0] as WorldEnvironment
		# Safely drill down to get the ProceduralSkyMaterial
		if world_env and world_env.environment and world_env.environment.sky:
			sky_mat = world_env.environment.sky.sky_material as ProceduralSkyMaterial
	else:
		world_env = null

func _process(delta: float) -> void:
	if not is_instance_valid(sun):
		find_sun()
		return 
		
	# NEW: Try to find the environment if it's missing
	if not is_instance_valid(world_env):
		find_environment()
	
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
	if sun == null: 
		return
		
	var normalized_time = time_of_day / 24.0
	var sun_angle = (normalized_time * 360.0) - 90.0
	sun.rotation_degrees.x = -sun_angle
	
	if sun_color and sun_color.gradient:
		sun.light_color = sun_color.gradient.sample(normalized_time)
		
	# FIX: Sample the curve directly!
	if sun_intensity:
		sun.light_energy = sun_intensity.sample(normalized_time)
		
	if sky_mat:
		var horizon_color = sky_horizon_gradient.gradient.sample(normalized_time)
		sky_mat.sky_top_color = sky_top_gradient.gradient.sample(normalized_time)
		sky_mat.sky_horizon_color = horizon_color
		
		# NEW: Make the ground match the horizon to remove the white line
		sky_mat.ground_horizon_color = horizon_color
		sky_mat.ground_bottom_color = horizon_color # Or a darker version of the horizon
