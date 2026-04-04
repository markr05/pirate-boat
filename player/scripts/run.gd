extends PlayerState

func enter() -> void:
	player.anim_tree.get("parameters/BaseMovement/playback").travel("Player_Walking")

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	
	# 1. DRAIN STAMINA
	player.stamina -= player.stamina_drain_rate * delta
	
	# 2. CALCULATE MOVEMENT FIRST (Crucial to prevent the "Stop" bug)
	var input_dir = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var direction = (player.transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	# We use sprint speed here, but it will be overridden by Walk state next frame if we transition
	var speed = player.sprint_speed * player.speed_multiplier
	var calc_speed = (speed / player.base_speed) * 2.0
	
	player.velocity.x = direction.x * speed
	player.velocity.z = direction.z * speed

	# 3. HANDLE JUMPING
	if Input.is_action_pressed("ui_accept") and player.is_on_floor():
		player.velocity.y = player.jump_velocity

	# 4. TRANSITION CHECKS
	# Check for Idle
	if input_dir == Vector2.ZERO:
		state_machine.transition_to("Idle")
		player.anim_tree.set("parameters/TimeScale/scale", 1)
		return
		
	# THE KICK-OUT: Transition to Walk if Shift is released OR if stamina hits 0
	# Because we set velocity ABOVE, the player will still be moving when they enter Walk
	if not Input.is_action_pressed("sprint") or player.stamina <= 0:
		state_machine.transition_to("Walk")
		# We don't return here yet so we can finish the move_and_slide for this frame
	
	# Check for Fishing
	if player.current_tool and "is_fishing" in player.current_tool and player.current_tool.is_fishing:
		state_machine.transition_to("Fish")
		player.anim_tree.set("parameters/TimeScale/scale", 1)
		return
	
	# 5. FINAL EXECUTION
	player.anim_tree.set("parameters/TimeScale/scale", calc_speed)
	player.move_and_slide()
