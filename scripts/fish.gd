extends PlayerState

func enter() -> void:
	player.anim_player.play("holding_rod", 0.3)
	player.anim_player.speed_scale = 1.0

func physics_update(delta: float) -> void:
	var friction = 20.0 * delta 
		
	player.velocity.x = move_toward(player.velocity.x, 0, friction)
	player.velocity.z = move_toward(player.velocity.z, 0, friction)
	
	player.apply_gravity(delta)
	player.move_and_slide()
	
	if not player.current_tool or not "is_fishing" in player.current_tool or not player.current_tool.is_fishing:
		state_machine.transition_to("Idle")
