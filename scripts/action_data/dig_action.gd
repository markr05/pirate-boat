extends ActionData
class_name DigActionData

@export var brush_radius: float = 1.0
@export var dig_strength: float = 0.2
@export var cooldown_ms: int = 500 # 500 milliseconds = 0.5 seconds
@export var stamina_use: int = 10

# This variable stays in memory as long as the resource is loaded
var next_available_time: int = 0

func execute_action(player: CharacterBody3D):
	# 1. Get the current game time in milliseconds
	var current_time = Time.get_ticks_msec()
	
	# 2. Check if we are still in cooldown
	if current_time < next_available_time:
		return # Exit early, don't dig
	
	# 3. If we passed the check, find the raycast
	var raycast = player.find_child("TerrainRayCast", true, false)
	
	if raycast and raycast.has_method("try_to_dig"):
		# 4. Set the new cooldown timestamp
		next_available_time = current_time + cooldown_ms
		
		# 5. Fire the dig
		if player.stamina >= stamina_use:
			player.stamina -= stamina_use
			raycast.try_to_dig(brush_radius, dig_strength)
