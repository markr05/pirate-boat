extends PlayerState

func enter() -> void:
	player.anim_tree.get("parameters/BaseMovement/playback").travel("Player_Walking")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	var speed = player.base_speed * player.speed_multiplier	
	var calc_speed = (speed / player.base_speed) * 2.0
	
	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity

	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	
	if input_dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		player.anim_tree.set("parameters/TimeScale/scale", 1)
	
		return
		
	if Input.is_action_pressed("sprint"):
		state_machine.transition_to("Run")
		player.anim_tree.set("parameters/TimeScale/scale", calc_speed)
		return

	if player.current_tool and "is_fishing" in player.current_tool and player.current_tool.is_fishing:
		state_machine.transition_to("Fish")
		player.anim_tree.set("parameters/TimeScale/scale", 1)
		return
		
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()


	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed
	
	player.anim_tree.set("parameters/TimeScale/scale", calc_speed)
		
	player.move_and_slide()
