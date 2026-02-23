extends MeshInstance3D

@export var target_tip_position: Vector3 = Vector3(0, -0.2, 0) # The "pin" spot

func _process(_delta):
	update_mesh_placement()
	update_mesh_rotation()

func update_mesh_placement():
	if not mesh: return
	
	var aabb = mesh.get_aabb()
	var mesh_height = aabb.size.y * scale.y
	var mesh_length = aabb.size.z * scale.z # The front-to-back length
	
	# 1. Base vertical position (staying below the bobber)
	var base_pos = Vector3(target_tip_position.x, target_tip_position.y + mesh_height / 2, target_tip_position.z)
	
	# 2. Offset the mesh backward so the "front" is at the pivot point
	# We move it back by half its length along its own local -Z axis
	# 'basis.z' is the local forward/backward vector in Godot
	var offset = basis.z * (mesh_length / 2.0)
	
	# 3. Apply the final position
	position = base_pos - offset

func update_mesh_rotation():
	var bobber = get_parent()
	if bobber and "velocity" in bobber:
		var vel = bobber.velocity
		
		# 1. Use the full velocity (X, Y, and Z) to allow vertical tilting
		# Note: We use negative velocity because your logic has the fish 
		# looking "away" from its movement (nose pinned to bobber).
		var move_dir = -vel 
		
		if move_dir.length_squared() > 0.01:
			var look_target = global_position + move_dir.normalized()
			
			# 2. Use a safe 'Up' vector check to prevent the "Gimbal Lock" flip
			# If move_dir is almost perfectly vertical, use Vector3.FORWARD as a backup up-vector
			var up_vector = Vector3.UP
			if abs(move_dir.normalized().dot(Vector3.UP)) > 0.99:
				up_vector = Vector3.FORWARD
				
			look_at(look_target, up_vector)
