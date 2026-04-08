extends EquippableItem

# Drag the child node containing FishingManager.gd here in inspector
@export var fishing_manager: Node 

@onready var bobber: CharacterBody3D = %Bobber
@onready var alert: Label3D = %Bobber/Alert
@onready var fishing_line_starter_marker: Marker3D = %FishingLineStarterMarker
@onready var bobber_start_marker: Marker3D = %BobberStartMarker
@onready var fishing_line: MeshInstance3D = %FishingLine
@onready var direction_label: Label = $FishingUI/MarginContainer/Label
@onready var distance_label: Label = $FishingUI/FishLine/Label
@onready var fish_line: TextureRect = $FishingUI/FishLine/Fish

@onready var anim_player: AnimationPlayer = get_tree().get_first_node_in_group("player_animations")

# --- SETTINGS ---
const THROW_FORCE = 15.0
const THROW_ARC = 3.0
const REEL_IN_SPEED = 3.0 # Sped up slightly for better feel
const REEL_OUT_SPEED = 3.0
const MIN_LENGTH = 1.0
const MAX_LENGTH = 100.0
const ROPE_STIFFNESS = 40.0
const CATCH_DISTANCE = 2.5

# --- STATE ---
var is_fishing: bool = false
var in_water: bool = false
var current_rope_length: float = 1.0
var cast_timer: float = 0.0
var fish_hooked: bool = false
var fish_caught: ItemData = null
var is_winding_up: bool = false
var fish_direction: String = ""
@export var rod: RodData = null
var _actual_tension: float = 0.0
var line_tension: int = 0
var max_tension: int = 100

var current_fish_xp: float = 0.0

func setup(player):
	super.setup(player)
	bobber.set_as_top_level(true)
	if fishing_line: fishing_line.set_as_top_level(true)
	bobber.set_physics_process(true)
	if fishing_line: fishing_line.hide()
	
	if fishing_manager and not fishing_manager.is_connected("fish_bit", _on_fish_bite_received):
		fishing_manager.fish_bit.connect(_on_fish_bite_received)
	
	if not bobber.is_connected("entered_water", _on_bobber_entered_water):
		bobber.entered_water.connect(_on_bobber_entered_water)

	# NEW: Play the holding animation as soon as we equip the rod!
	if anim_player and not is_fishing:
		anim_player.play("holding_rod", 0.2)
		
func set_item_data(item_data: ItemData):
	if item_data is RodData:
		rod = item_data
	
	if rod.lure != null:
		if bobber.has_method("set_bobber_mesh"):
				bobber.set_bobber_mesh(rod.lure)
				
		else:
			if bobber.has_method("reset_bobber_mesh"):
				bobber.reset_bobber_mesh()

func _on_bobber_entered_water():
	if is_fishing and not in_water:
		in_water = true
		# End the cast timer early so rope physics take over immediately in water
		cast_timer = 0.0 
		if fishing_manager: fishing_manager.start_waiting()
		
		var current_dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
		current_rope_length = current_dist

func primary_action():
	if not is_fishing:
		start_fishing()

func _physics_process(delta: float) -> void:
	if is_fishing:
		var distance_to_player = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
		distance_label.text = str(round(distance_to_player))
		fish_line.position.x = -450 + line_tension * 10
		if is_winding_up:
			# GLUE TO ROD TIP: Keep the bobber exactly at the marker while the arm moves
			bobber.global_position = fishing_line_starter_marker.global_position
			bobber.velocity = Vector3.ZERO
			_refresh_line()
			return # Skip all other physics this frame
			
		if cast_timer > 0:
			cast_timer -= delta
			# FREE SPOOL: Grow rope length to match distance while flying
			var current_dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
			if current_dist > current_rope_length:
				current_rope_length = current_dist
				
		if fish_hooked:
			_process_tension(delta)
		
		_refresh_line()
		_handle_inputs(delta)
		_handle_physics(delta)
	else:
		bobber.global_position = bobber_start_marker.global_position
		bobber.velocity = Vector3.ZERO
		if fishing_line: fishing_line.hide()

func _handle_inputs(delta: float):
	if Input.is_action_pressed("fire_secondary"):
		current_rope_length += REEL_OUT_SPEED * delta
	
	if Input.is_action_pressed("fire_primary"):
		if fish_hooked:
			var move = false
			if Input.is_action_pressed("ui_down") and fish_direction == "UP":
				move = true
			if Input.is_action_pressed("ui_up") and fish_direction == "DOWN":
				move = true
			if Input.is_action_pressed("ui_right") and fish_direction == "LEFT":
				move = true
			if Input.is_action_pressed("ui_left") and fish_direction == "RIGHT":
				move = true
			if move:
				current_rope_length -= REEL_IN_SPEED * delta
				var dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
				if current_rope_length > dist + 1.0:
					current_rope_length = dist
		else:
			current_rope_length -= REEL_IN_SPEED * delta
			var dist = bobber.global_position.distance_to(fishing_line_starter_marker.global_position)
			if current_rope_length > dist + 1.0:
				current_rope_length = dist
	
	current_rope_length = clamp(current_rope_length, MIN_LENGTH, MAX_LENGTH)

func _handle_physics(delta: float):
	var rod_tip = fishing_line_starter_marker.global_position
	var dist = bobber.global_position.distance_to(rod_tip)
	
	if cast_timer <= 0.0 and dist < CATCH_DISTANCE:
		stop_fishing()
		return 

	var is_underwater = bobber.get("is_floating") or in_water

	if not bobber.is_on_floor() and not is_underwater:
		bobber.velocity += player_ref.get_gravity() * delta
	elif is_underwater:
		bobber.velocity *= 0.9 

	var is_reeling = Input.is_action_pressed("fire_primary")
	if dist > current_rope_length and cast_timer <= 0:
		var direction_to_rod = (rod_tip - bobber.global_position).normalized()
		var stretch = dist - current_rope_length
		
		var horizontal_pull = Vector3(direction_to_rod.x, 0, direction_to_rod.z)
		var vertical_pull = Vector3(0, direction_to_rod.y, 0)
		
		bobber.velocity += horizontal_pull * (stretch * ROPE_STIFFNESS) * delta
		bobber.velocity += vertical_pull * (stretch * ROPE_STIFFNESS * 0.4) * delta
		
		bobber.velocity *= 0.95
		
		var vel_away = bobber.velocity.dot(-direction_to_rod)
		if vel_away > 0:
			bobber.velocity += direction_to_rod * vel_away
			
		var force_multiplier = 4.0 if is_reeling else 1.0
		bobber.velocity += direction_to_rod * (stretch * ROPE_STIFFNESS * force_multiplier) * delta

	bobber.move_and_slide()
	if bobber.get_slide_collision_count() > 0:
		for i in bobber.get_slide_collision_count():
			var collision = bobber.get_slide_collision(i)
			var collider = collision.get_collider()
		
			# 1. If it's underwater or fighting a fish, hitting the lake floor is normal.
			if in_water or fish_hooked:
				# Just kill the momentum so it doesn't clip through the ground
				bobber.velocity = Vector3.ZERO 
				bobber.global_position += collision.get_normal() * 0.05
				continue # Skip the cancel logic below
				
			# 2. If it hits dry land BEFORE ever touching the water (a bad cast)
			print("Hit land! Canceling cast.")
			stop_fishing()
			return # Stop processing physics this frame

func start_fishing():
	is_fishing = true
	is_winding_up = true 
	in_water = false
	cast_timer = 2.0 
	
	# 1. Fire the OneShot action in the Tree
	# This overrides the 'holding_rod' pose temporarily
	player_ref.anim_tree.set("parameters/FishingAction/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_FIRE)

	player_ref.look_limit_center = player_ref.look_rotation
	player_ref.is_look_limited = true
	
	if bobber.has_method("reset_bobber"): bobber.reset_bobber()
	if fishing_line: fishing_line.show()
	
	# Snap the bobber to the rod tip
	bobber.global_position = fishing_line_starter_marker.global_position
	bobber.velocity = Vector3.ZERO
	
	# 2. Wait for the "Forward Swing" point of your animation
	# Adjust this timer so the bobber flies out exactly when the arm moves forward
	await get_tree().create_timer(1.0).timeout
	
	if not is_fishing: return

	is_winding_up = false
	current_rope_length = 1.5 
	var camera = player_ref.camera
	var throw_dir = -camera.global_transform.basis.z 
	
	bobber.global_position = fishing_line_starter_marker.global_position
	bobber.velocity = throw_dir * THROW_FORCE
	bobber.velocity.y += THROW_ARC
	
	anim_player.play("idle_fishing", 0.5)

func _on_fish_bite_received(fish_data: FishData):
	if not fish_data: return
	
	# 1. Use the ItemDB to find the physical ItemData that matches the fish name
	var item_result = ItemDB.get_item_by_name(fish_data.fish_name)
	
	# 2. Safety check: if the database couldn't find the item, don't let the player catch nothing
	if not item_result:
		push_error("FishingRod: No ItemData found in ItemDb for " + fish_data.fish_name)
		return

	# 3. Check if player is already holding the reel button (prevents instant-catch exploits)
	if Input.is_action_pressed("fire_primary"):
		if fishing_manager:
			fishing_manager.start_waiting() 
		return

	# 4. Set up the "Potential Catch"
	fish_hooked = true
	fish_caught = item_result       # This is the ItemData (for inventory)
	current_fish_xp = fish_data.xp_amount # Store XP from the FishData resource
	
	if is_fishing and bobber:
		alert.visible = true
		bobber.velocity.y -= 4.0
		
		var timer = 0.0
		var reaction_time = 1.0 # 1 second to react
		var hooked_successfully = false
		
		# 5. The "Reaction" window
		while timer < reaction_time:
			if Input.is_action_just_pressed("fire_primary"):
				hooked_successfully = true
				# Pass the ItemData to the bobber so it shows the fish mesh
				bobber.set_mesh(item_result) 
				break
			
			await get_tree().process_frame
			timer += get_process_delta_time()
			
			# If player stops fishing or rod is unequipped during the wait
			if not is_fishing: return
		
		# 6. Final Result
		if hooked_successfully:
			alert.visible = false
			fish_fight()
		else:
			_fail_fishing()

func _process_tension(delta: float):
	var rod_tip = fishing_line_starter_marker.global_position
	var dir_to_bobber = rod_tip.direction_to(bobber.global_position)
	
	var pull_away_speed = bobber.velocity.dot(dir_to_bobber)
	var is_reeling = Input.is_action_pressed("fire_primary")
	var is_letting_out = Input.is_action_pressed("fire_secondary")
	
	var tension_change = 0.0
	
	# Priority 1: If letting out line, tension drops at a constant, fast rate
	if is_letting_out:
		tension_change = -30.0 
	else:
		# Priority 2: The fish is actively pulling away
		if pull_away_speed > 0.01:
			if is_reeling:
				# DANGER: Player is pulling AGAINST the fish. Massive tension spike!
				tension_change = 40.0 + (pull_away_speed * 60.0) 
			else:
				# Fish is pulling, but player is just holding the rod. Slow, safe tension climb.
				tension_change = 5.0 + (pull_away_speed * 15.0) 
		
		# Priority 3: The fish is resting, darting sideways, or coming towards you
		else:
			if is_reeling:
				tension_change = 10.0 # Slow cooldown (reeling while the fish rests)
			else:
				tension_change = -10.0 # Normal cooldown (doing nothing)
			
	_actual_tension += tension_change * delta
	_actual_tension = clamp(_actual_tension, 0.0, float(max_tension))
	line_tension = int(_actual_tension)
	
	# Print updated stats (You can comment this out once it feels right)
	print("Speed: %.3f | Change/sec: %.2f | Tension: %d" % [pull_away_speed, tension_change, line_tension])
	
	if line_tension >= max_tension:
		print("Line Snapped!")
		stop_fishing()
		
func fish_fight():
	bobber.set("has_fish", true)
	
	while fish_hooked and is_fishing:
		var rod_pos = fishing_line_starter_marker.global_position
		
		# Pick a completely random direction on the 3D XZ plane (0 to 360 degrees)
		# TAU is a GDScript constant for 360 degrees in radians.
		var random_angle = randf_range(deg_to_rad(50), deg_to_rad(310)) 
		var horizontal_pull = Vector3(cos(random_angle), 0, sin(random_angle))
		
		# --- PLAYER-RELATIVE DIRECTION DETECTION ---
		var pull_dir_world = horizontal_pull.normalized()
		var cam_basis = player_ref.camera.global_transform.basis

		var local_z = pull_dir_world.dot(cam_basis.z) 
		var local_x = pull_dir_world.dot(cam_basis.x) 

		# Determine the primary direction (The "WASD" logic)
		if abs(local_z) > abs(local_x):
			if local_z < 0:
				fish_direction = "UP"
				direction_label.text = "S"
			else:
				fish_direction = "DOWN"
				direction_label.text = "W"
		else:
			if local_x > 0:
				fish_direction = "RIGHT"
				direction_label.text = "A"
			else:
				fish_direction = "LEFT"
				direction_label.text = "D"
		
		horizontal_pull.y = 0 
		
		var tilt_angle = deg_to_rad(-8)
		if bobber.is_on_floor():
			tilt_angle = deg_to_rad(5)
		var pull_direction = horizontal_pull.rotated(horizontal_pull.cross(Vector3.UP).normalized(), tilt_angle)
		
		var pull_duration = randf_range(0.8, 2.0)
		var timer = 0.0
		
		while timer < pull_duration and fish_hooked:
			# If the player is reeling, the fish fights harder!
			var reeling_bonus = 1.5 if Input.is_action_pressed("fire_primary") else 1.0
			var pull_force = 22.0 * reeling_bonus 
			
			bobber.velocity += pull_direction * pull_force * get_physics_process_delta_time()
			
			await get_tree().physics_frame
			timer += get_physics_process_delta_time()
			
			if bobber.global_position.distance_to(rod_pos) < CATCH_DISTANCE:
				break

func _fail_fishing():
	alert.visible = false
	fish_hooked = false
	fish_caught = null
	if fishing_manager:
		fishing_manager.start_waiting() 
	
func stop_fishing():
	# 1. Handle Fish Logic
	fish_line.position.x = -450
	direction_label.text = ""
	bobber.reset_mesh()
	bobber.set("has_fish", false)
	alert.visible = false
	
	if fish_hooked and fish_caught and line_tension < max_tension:
		player_ref.add_to_inventory(fish_caught)
		player_ref.update_xp("fishing", current_fish_xp)
	
	# 2. Reset State Variables
	is_fishing = false
	in_water = false
	fish_hooked = false
	fish_caught = null
	is_winding_up = false
	
	_actual_tension = 0.0
	line_tension = 0
	
	# 3. Physics & Bobber Cleanup
	# Reset the bobber's parent-level velocity and move it back
	bobber.velocity = Vector3.ZERO
	bobber.global_position = bobber_start_marker.global_position
	if fishing_line: fishing_line.hide()
	
	# 4. Animation & Camera Cleanup
	player_ref.is_look_limited = false
	
	# Reset the AnimationTree OneShot (stops the throw if it was still playing)
	player_ref.anim_tree.set("parameters/FishingAction/request", AnimationNodeOneShot.ONE_SHOT_REQUEST_ABORT)
	
	
	# Play the base holding animation
	if anim_player:
		anim_player.play("holding_rod", 0.4)
		anim_player.speed_scale = 1.0

	# 5. Manager Cleanup
	if fishing_manager: 
		fishing_manager.reset()

func _refresh_line():
	if not fishing_line: return
	var start = fishing_line_starter_marker.global_position
	var end = bobber.global_position
	var dist = start.distance_to(end)
	
	if dist < 0.1:
		fishing_line.hide()
		return
	
	fishing_line.show()
	fishing_line.global_position = (start + end) / 2.0
	
	if abs(start.x - end.x) < 0.01 and abs(start.z - end.z) < 0.01:
		fishing_line.look_at(end, Vector3.RIGHT)
	else:
		fishing_line.look_at(end, Vector3.UP)
	
	fishing_line.rotation_degrees.x -= 90 
	
	if fishing_line.mesh is CylinderMesh or fishing_line.mesh is CapsuleMesh:
		fishing_line.mesh.height = dist
