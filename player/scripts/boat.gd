extends PlayerState

func enter() -> void:
	# 1. Put away items and turn off player collision
	player.inventory.select_slot(-1) 
	player.collider.disabled = true
	player.camera_controller.enter_seat()
	
	# 2. Snap to the seat immediately
	if player.current_boat and player.current_boat.seat_node:
		player.global_transform = player.current_boat.seat_node.global_transform
		
	player.anim_player.play("Pirate_Sit", 0.2)

func physics_update(_delta: float) -> void:
	# Safety check in case the boat is destroyed
	if not player.current_boat:
		state_machine.transition_to("Idle")
		return
		
	# Continuously stick to the boat as it moves
	player.global_transform = player.current_boat.seat_node.global_transform
	
	# --- SAILBOAT CONTROLS ---
	
	# 1. Steer the Rudder (A and D keys / Left Joystick)
	# This gets a value from -1.0 to 1.0
	var steer_direction = Input.get_axis("ui_right", "ui_left") 
	player.current_boat.set_steering(steer_direction)
		
	# 2. Drop / Raise Sail (Using your new dedicated button!)
	if Input.is_action_just_pressed("boat_action"):
		player.current_boat.toggle_sail()
		
	# --- EXIT BOAT ---
	# Pressing jump will stand the player up
	if Input.is_action_just_pressed("ui_accept"):
		state_machine.transition_to("Idle")

func exit() -> void:
	# Center the rudder when we stand up so the boat stops turning
	if player.current_boat and player.current_boat.has_method("set_steering"):
		player.current_boat.set_steering(0.0)
		
	player.collider.disabled = false
	
	# Eject slightly upward and reset camera
	var boat_yaw = player.global_rotation.y
	player.global_position.y += 1.5
	player.camera_controller.exit_seat(boat_yaw)
	
	player.current_boat = null
