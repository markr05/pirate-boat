extends Node3D
class_name CameraController

@export var player: CharacterBody3D
@export var look_speed: float = 0.002

var look_rotation: Vector2 = Vector2.ZERO
var is_enabled: bool = true
var is_seated: bool = false
var is_look_limited: bool = false
var look_limit_center: Vector2 = Vector2.ZERO

func _ready() -> void:
	if player:
		look_rotation.y = player.rotation.y
	look_rotation.x = rotation.x

func _unhandled_input(event: InputEvent) -> void:
	if not is_enabled:
		return

	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		look_rotation.x -= event.relative.y * look_speed
		look_rotation.y -= event.relative.x * look_speed
		
		# Clamp up/down looking
		look_rotation.x = clamp(look_rotation.x, deg_to_rad(-75), deg_to_rad(85))
		
		# Apply fishing/seated limits
		if is_look_limited:
			look_rotation.x = clamp(look_rotation.x, look_limit_center.x - deg_to_rad(45), look_limit_center.x + deg_to_rad(45))
			look_rotation.y = clamp(look_rotation.y, look_limit_center.y - deg_to_rad(45), look_limit_center.y + deg_to_rad(45))
		elif is_seated:
			look_rotation.y = clamp(look_rotation.y, deg_to_rad(-100), deg_to_rad(100))

		# Apply rotations
		if is_seated:
			rotation.y = look_rotation.y
			rotation.x = look_rotation.x
		else:
			player.rotation.y = look_rotation.y
			rotation.x = look_rotation.x
			rotation.y = 0 

# --- HELPERS FOR BOAT MODES ---
func enter_seat():
	is_seated = true
	look_rotation = Vector2.ZERO 
	rotation = Vector3.ZERO

func exit_seat(boat_yaw: float):
	is_seated = false
	look_rotation.y = boat_yaw
	look_rotation.x = 0
	rotation = Vector3.ZERO
	player.rotation.y = boat_yaw
