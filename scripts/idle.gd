extends PlayerState

func enter() -> void:
	player.anim_player.play("player_idle", 0.2)
	player.anim_player.speed_scale = 1.0
	player.velocity.x = 0
	player.velocity.z = 0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()

	if not player.is_on_floor():
		pass # Transition to a fall state later if you want

	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity
		
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if input_dir != Vector2.ZERO:
		state_machine.transition_to("Walk")
		
	# Check if we started fishing
	if player.current_tool and player.current_tool.has_method("is_fishing") and player.current_tool.is_fishing:
		state_machine.transition_to("Fish")
