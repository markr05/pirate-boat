extends PlayerState

func enter() -> void:
	player.anim_player.play("player_idle", 0.2)
	player.anim_player.speed_scale = 1.0

func physics_update(delta: float) -> void:
	player.velocity.x = move_toward(player.velocity.x, 0, player.base_speed)
	player.velocity.z = move_toward(player.velocity.z, 0, player.base_speed)
	
	player.apply_gravity(delta)
	player.move_and_slide()

	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity
		
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		state_machine.transition_to("Walk")
		
	if player.current_tool and "is_fishing" in player.current_tool and player.current_tool.is_fishing:
		state_machine.transition_to("Fish")
