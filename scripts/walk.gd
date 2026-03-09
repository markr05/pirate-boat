extends PlayerState

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		return
		
	if Input.is_action_pressed("sprint"):
		state_machine.transition_to("Run")
		return

	if player.current_tool and "is_fishing" in player.current_tool and player.current_tool.is_fishing:
		state_machine.transition_to("Fish")
		return

	var speed = player.base_speed * player.speed_multiplier
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	
	player.anim_player.play("Player_Walking", 0.3)
	player.anim_player.speed_scale = (speed / player.base_speed) * 2.0
	
	player.move_and_slide()
