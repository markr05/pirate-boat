@tool
extends Node3D

signal spawning_finished

@export_group("Execution Order")
@export var target_scatterer: Node3D 
@export var refresh: bool = false: 
	set(value):
		if Engine.is_editor_hint():
			generate_items()

@export_group("Scatter Settings")
@export var custom_seed: int = 12483
@export var items_to_spawn: Array[PackedScene]
@export var spawn_count: int = 200
@export var inclusion_layer: int = 7
@export var exclusion_layer: int = 6
@export var ground_layer: int = 1
@export var box_size: Vector3 = Vector3(5000, 100, 5000)
@export var freeze_spawned_items: bool = true

# --- NEW VARIABLE HERE ---
@export var max_slope_angle: float = 30.0 ## Trees won't spawn on ground steeper than this angle.

@export_group("Randomization")
@export var y_offset_range: Vector2 = Vector2(0.0, 0.0) 
@export var scale_range: Vector2 = Vector2(0.8, 1.2)
@export var max_tilt_degrees: float = 10.0

var rng = RandomNumberGenerator.new()

func _ready():
	if Engine.is_editor_hint():
		return
		
	rng.seed = custom_seed
	
	if target_scatterer:
		target_scatterer.spawning_finished.connect(_on_target_finished)
	else:
		call_deferred("generate_items")

func _on_target_finished():
	call_deferred("generate_items")

func generate_items():
	for child in get_children():
		if child.has_meta("is_scattered_item"):
			child.queue_free()

	if items_to_spawn.is_empty():
		return
	
	var space_state = get_world_3d().direct_space_state
	
	var inclusion_bit = 1 << (inclusion_layer - 1)
	var exclusion_bit = 1 << (exclusion_layer - 1)
	var ground_bit = 1 << (ground_layer - 1)

	var spawned_so_far = 0
	var attempts = 0
	var max_attempts = spawn_count * 20 # Increased slightly for slope filtering

	while spawned_so_far < spawn_count and attempts < max_attempts:
		attempts += 1
		
		var random_x = rng.randf_range(-box_size.x / 2.0, box_size.x / 2.0)
		var random_z = rng.randf_range(-box_size.z / 2.0, box_size.z / 2.0)

		var ray_origin = global_position + Vector3(random_x, box_size.y / 2.0, random_z)
		var ray_end = ray_origin + Vector3(0, -box_size.y, 0)

		var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_end)
		query.collision_mask = inclusion_bit | exclusion_bit | ground_bit

		var result = space_state.intersect_ray(query)

		if result:
			var hit_layer = result.collider.collision_layer
			
			if hit_layer & exclusion_bit:
				continue
			
			if hit_layer & inclusion_bit:
				var floor_query = PhysicsRayQueryParameters3D.create(result.position, ray_end)
				floor_query.collision_mask = ground_bit
				var floor_result = space_state.intersect_ray(floor_query)
				
				if floor_result:
					# --- SLOPE CHECK LOGIC ---
					# result.normal tells us which way the ground is facing.
					# angle_to(Vector3.UP) tells us how many radians it tilts away from flat ground.
					var slope_angle = rad_to_deg(floor_result.normal.angle_to(Vector3.UP))
					
					if slope_angle <= max_slope_angle:
						_spawn_mesh(floor_result.position)
						spawned_so_far += 1 

	if not is_inside_tree():
		return

	if not Engine.is_editor_hint():
		# Safety check: make sure the tree still exists before awaiting
		var tree = get_tree()
		if tree:
			await tree.physics_frame
			await tree.physics_frame 
			spawning_finished.emit()
			print(name, " finished spawning ", spawned_so_far, " items.")

func _spawn_mesh(pos: Vector3):
	var random_index = rng.randi() % items_to_spawn.size()
	var scene = items_to_spawn[random_index]
	
	var instance = scene.instantiate() as Node3D
	instance.set_meta("is_scattered_item", true) 
	add_child(instance)
	
	if instance is RigidBody3D:
		instance.freeze = freeze_spawned_items
		instance.freeze_mode = RigidBody3D.FREEZE_MODE_STATIC
	
	if Engine.is_editor_hint():
		instance.owner = get_tree().edited_scene_root 
		
	var random_y_offset = rng.randf_range(y_offset_range.x, y_offset_range.y)
	instance.global_position = pos + Vector3(0, random_y_offset, 0)
	
	var s = rng.randf_range(scale_range.x, scale_range.y)
	instance.scale = Vector3(s, s, s)
	
	var rot_y = rng.randf_range(0, TAU) 
	var tilt_x = deg_to_rad(rng.randf_range(-max_tilt_degrees, max_tilt_degrees))
	var tilt_z = deg_to_rad(rng.randf_range(-max_tilt_degrees, max_tilt_degrees))
	
	instance.rotation = Vector3(tilt_x, rot_y, tilt_z)
