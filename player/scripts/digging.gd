extends RayCast3D

@export var terrain: Terrain3D
@export var bedrock_level: float = 10.3

func try_to_dig(radius: float, strength: float):
	if is_colliding():
		var hit_pos = get_collision_point()
		dig_crater(hit_pos, radius, strength)

func dig_crater(hit_pos: Vector3, radius: float, strength: float):
	if not terrain or not terrain.data:
		print("Terrain or Data missing!")
		return

	var data = terrain.data
	var snapped_pos = hit_pos.round()
	var bounds = ceil(radius)
	
	for x in range(-bounds, bounds + 1):
		for z in range(-bounds, bounds + 1):
			var offset = Vector3(x, 0, z)
			
			if offset.length() <= radius:
				var target_point = snapped_pos + offset
				var current_h = data.get_height(target_point)
				
				# Apply bedrock limit
				var desired_height = current_h - strength
				var final_height = max(desired_height, bedrock_level)
				
				data.set_height(target_point, final_height)

	# Refresh the maps
	if data.has_method("update_maps"):
		data.update_maps()
	elif data.has_method("force_update_maps"):
		data.force_update_maps()
