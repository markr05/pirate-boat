extends Node3D

# Matches your shader parameters
@export var wave_height: float = 0.5 
@export var wave_speed: float = 1.0 

func get_wave_height_at_position(pos: Vector3, time: float) -> float:
	# Returns the Y offset based on the same math as your shader
	var calculated_y = (sin(time * wave_speed + pos.x) * cos(time * wave_speed + pos.z)) * wave_height
	return calculated_y
