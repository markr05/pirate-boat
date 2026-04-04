extends CharacterBody3D

@export var mesh_instance: MeshInstance3D
@export var collision_shape: CollisionShape3D
@export var speed: float = 3.5
@export var damage: int = 5

var target: Node3D = null

func _ready() -> void:
	# Find the player as soon as the enemy spawns
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		target = players[0]

func _physics_process(delta: float) -> void:
	# 1. Apply Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Chase the Target
	if target:
		# Calculate the vector pointing from the enemy to the player
		var direction = global_position.direction_to(target.global_position)
		
		# Zero out the Y axis so the enemy doesn't try to fly up into the air
		direction.y = 0 
		direction = direction.normalized()
		
		velocity.x = direction.x * speed
		velocity.z = direction.z * speed
	
	# 3. Move
	move_and_slide()


func _on_damage_zone_body_entered(body: Node3D) -> void:
	# Check if the thing we just touched is in the player group
	if body.is_in_group("player"):
		# Check if it has our damage function
		if body.has_method("take_damage"):
			body.take_damage(damage)
