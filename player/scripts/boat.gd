extends PlayerState

var stroke_cooldown: float = 0.0

func enter() -> void:
	player.inventory.select_slot(-1) 
	player.collider.disabled = true
	player.camera_controller.enter_seat()
	
	if player.current_boat and player.current_boat.seat_node:
		player.global_transform = player.current_boat.seat_node.global_transform
		
	#player.anim_player.play("Pirate_Sit", 0.2)
	stroke_cooldown = 0.0 # Reset the rowing rhythm

func physics_update(delta: float) -> void:
	if not player.current_boat:
		state_machine.transition_to("Idle")
		return
		
	player.global_transform = player.current_boat.seat_node.global_transform
	
	# --- DYNAMIC CONTROLS ---
	
	# 1. ROWBOAT CONTROLS
	if player.current_boat.has_method("row_left"):
		stroke_cooldown -= delta
		var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
		
		# If the player is pushing a direction and the boat is ready for another stroke
		if input_dir.length() > 0.1 and stroke_cooldown <= 0.0:
			
			# CRITICAL: Wake up the rigidbody in case it fell asleep in the water
			player.current_boat.sleeping = false 
			
			# Holding Forward (W) -> Stroke both oars to go straight
			if input_dir.y < -0.5: 
				player.current_boat.row_left()
				player.current_boat.row_right()
				stroke_cooldown = player.current_boat.stroke_duration
				
			# Holding Right (D) -> Stroke Left oar to push the boat right
			elif input_dir.x > 0.5:
				player.current_boat.row_left()
				stroke_cooldown = player.current_boat.stroke_duration
				
			# Holding Left (A) -> Stroke Right oar to push the boat left
			elif input_dir.x < -0.5:
				player.current_boat.row_right()
				stroke_cooldown = player.current_boat.stroke_duration

	# 2. SAILBOAT CONTROLS
	elif player.current_boat.has_method("set_steering"):
		var steer_direction = Input.get_axis("ui_right", "ui_left") 
		player.current_boat.set_steering(steer_direction)
			
		if Input.is_action_just_pressed("boat_action"):
			if player.current_boat.has_method("toggle_sail"):
				player.current_boat.toggle_sail()
	
	# --- EXIT BOAT ---
	if Input.is_action_just_pressed("ui_accept"):
		state_machine.transition_to("Idle")

func exit() -> void:
	if player.current_boat and player.current_boat.has_method("set_steering"):
		player.current_boat.set_steering(0.0)
		
	player.collider.disabled = false
	
	var boat_yaw = player.global_rotation.y
	player.global_position.y += 1.5
	player.camera_controller.exit_seat(boat_yaw)
	
	player.current_boat = null
