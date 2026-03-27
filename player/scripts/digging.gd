extends RayCast3D

@export var terrain: Terrain3D
@export var bedrock_level: float = 10.3

func try_to_dig(radius: float, strength: float):
	if is_colliding():
		var hit_pos = get_collision_point()
		
		# 1. Dig the hole
		dig_crater(hit_pos, radius, strength)
		
		# 2. Hide the grass
		hide_floating_grass(hit_pos, radius)
		
		# 3. NEW: Wake up nearby items (Coconuts, Fish, etc.)
		wake_nearby_objects(hit_pos, radius)

func wake_nearby_objects(center_pos: Vector3, radius: float):
	# We create a temporary sphere check to find physics bodies
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	
	# Create a sphere shape slightly larger than the hole
	var sphere = SphereShape3D.new()
	sphere.radius = radius + 1.0 
	
	query.shape = sphere
	query.transform = Transform3D(Basis(), center_pos)
	# Use the collision mask that your items/coconuts are on (usually Layer 1)
	query.collision_mask = 1 
	
	var results = space_state.intersect_shape(query)
	
	for dict in results:
		var body = dict["collider"]
		# If the object is a RigidBody3D (like a coconut), force it to wake up
		if body is RigidBody3D:
			body.sleeping = false
			# Give it a tiny microscopic nudge to ensure the engine re-checks gravity
			body.apply_central_impulse(Vector3.DOWN * 0.01)

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
				
				var desired_height = current_h - strength
				var final_height = max(desired_height, bedrock_level)
				data.set_height(target_point, final_height)

	# Refresh the ground visual
	if data.has_method("update_maps"):
		data.update_maps()
	elif data.has_method("force_update_maps"):
		data.force_update_maps()

func hide_floating_grass(center_pos: Vector3, radius: float):
	var mmis = []
	var grass_radius = radius * 1.5
	_find_all_multimeshes(terrain, mmis)
	
	var radius_sq = grass_radius * grass_radius
	var center_2d = Vector2(center_pos.x, center_pos.z)
	
	for mmi in mmis:
		if not mmi.multimesh: continue
		var mm = mmi.multimesh
		
		for i in range(mm.instance_count):
			var t = mm.get_instance_transform(i)
			
			var global_pos = mmi.global_transform * t.origin
			var blade_2d = Vector2(global_pos.x, global_pos.z)
			
			if blade_2d.distance_squared_to(center_2d) <= radius_sq:
				
				# THE FIX: Shrink the grass to microscopic size instead of moving it.
				# We use 0.001 instead of a pure 0 to prevent shader math errors.
				t.basis = t.basis.scaled(Vector3(0.001, 0.001, 0.001))
				
				mm.set_instance_transform(i, t)

# Recursive function to hunt down the MultiMesh nodes Terrain3D tries to hide
func _find_all_multimeshes(node: Node, result: Array):
	if node is MultiMeshInstance3D:
		result.append(node)
	
	# The 'true' argument is the secret weapon here. 
	# It allows us to access internal/hidden nodes created by C++ plugins.
	for child in node.get_children(true):
		_find_all_multimeshes(child, result)
