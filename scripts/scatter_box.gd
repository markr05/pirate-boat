extends Node3D

@export_group("Scatter Settings")
@export var custom_seed: int = 238
@export var items_to_spawn: Array[PackedScene]
@export var spawn_count: int = 50
@export var box_size: Vector3 = Vector3(50, 20, 50)

@export_group("Randomization")
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
@export var max_tilt_degrees: float = 10.0

var rng = RandomNumberGenerator.new()

func _ready():
	rng.seed = custom_seed
	call_deferred("generate_items")

func generate_items():
	if items_to_spawn.is_empty():
		return

	var space_state = get_world_3d().direct_space_state

	for i in range(spawn_count):
		var random_x = rng.randf_range(-box_size.x / 2.0, box_size.x / 2.0)
		var random_z = rng.randf_range(-box_size.z / 2.0, box_size.z / 2.0)

		var ray_origin = global_position + Vector3(random_x, box_size.y / 2.0, random_z)
		var ray_end = ray_origin + Vector3(0, -box_size.y, 0)

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		
		# --- FIX: COLLISION MASKING ---
		# We need the ray to see the ground (Layer 1) AND the exclusion (Layer 6).
		# Layer 1 = 1, Layer 6 = 32. Total mask = 33.
		query.collision_mask = 1 | 32 

		var result = space_state.intersect_ray(query)

		if result:
			# If the thing we hit is on Layer 6, 'continue' skips this placement
			if result.collider.collision_layer & 32:
				continue
				
			_spawn_mesh(result.position)

func _spawn_mesh(pos: Vector3):
	var random_index = rng.randi() % items_to_spawn.size()
	var scene = items_to_spawn[random_index]
	
	var instance = scene.instantiate() as Node3D
	add_child(instance)
	instance.global_position = pos
	
	var s = rng.randf_range(scale_range.x, scale_range.y)
	instance.scale = Vector3(s, s, s)
	
	var rot_y = rng.randf_range(0, TAU) 
	var tilt_x = deg_to_rad(rng.randf_range(-max_tilt_degrees, max_tilt_degrees))
	var tilt_z = deg_to_rad(rng.randf_range(-max_tilt_degrees, max_tilt_degrees))
	
	instance.rotation = Vector3(tilt_x, rot_y, tilt_z)
