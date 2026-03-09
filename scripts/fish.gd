extends PlayerState

func enter() -> void:
	player.velocity.x = 0
	player.velocity.z = 0
	player.anim_player.play("holding_rod", 0.3)
	player.anim_player.speed_scale = 1.0

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	# Check if we stopped fishing
	if not player.current_tool or not player.current_tool.has_method("is_fishing") or not player.current_tool.is_fishing:
		state_machine.transition_to("Idle")
