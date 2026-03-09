extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		return
		
	if not Input.is_action_pressed("sprint"):
		state_machine.transition_to("Walk")
		return

	var speed = player.sprint_speed * player.speed_multiplier
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	
	# Assuming you use the same animation but faster, or change to "Player_Running"
	player.anim_player.play("Player_Walking", 0.3) 
	player.anim_player.speed_scale = (speed / player.base_speed) * 2.0
	
	player.move_and_slide()
