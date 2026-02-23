extends CharacterBody3D

signal entered_water 

@export var float_offset: float = 0.2
@export var wave_height: float = 0.5 
@export var wave_speed: float = 1.0 


var is_floating: bool = false
var has_fish: bool = false
var base_water_level: float = 10.0

@onready var water_detector: Area3D = $WaterDetector

func _ready() -> void:
	water_detector.area_entered.connect(_on_area_entered)
	water_detector.area_exited.connect(_on_area_exited)

func _physics_process(delta: float) -> void:
	if is_floating:
		# Calculate Wave
		var time = Time.get_ticks_msec() / 1000.0
		var wave_y = 0.0
		var ocean_areas = water_detector.get_overlapping_areas()
		
		if ocean_areas.size() > 0:
			var ocean_node = ocean_areas[0].get_parent()
			if ocean_node.has_method("get_wave_height_at_position"):
				wave_y = ocean_node.get_wave_height_at_position(global_position, time)
				if "wave_height" in ocean_node:
					wave_height = ocean_node.wave_height

		# Bobbing Logic
		var target_y = base_water_level + wave_y + float_offset
		if has_fish: target_y -= 4.0 # Sinks if fish is on
			
		global_position.y = move_toward(global_position.y, target_y - 0.5, 2.0 * delta)
		
		# Water Drag
		velocity.x = move_toward(velocity.x, 0, 1.0 * delta)
		velocity.z = move_toward(velocity.z, 0, 1.0 * delta)
	else:
		# Air Gravity
		if not is_on_floor():
			velocity += get_gravity() * delta

	move_and_slide()

func _on_area_entered(area: Area3D) -> void:
	if area.is_in_group("water"):
		if not is_floating:
			is_floating = true
			base_water_level = area.global_position.y 
			velocity = Vector3.ZERO
			emit_signal("entered_water")

func _on_area_exited(area: Area3D) -> void:
	if area.is_in_group("water"):
		# Only stop floating if we are significantly above water (prevents glitching on wave crests)
		if global_position.y > base_water_level + wave_height + 2.0:
			is_floating = false

func reset_bobber():
	is_floating = false
	has_fish = false
	velocity = Vector3.ZERO
