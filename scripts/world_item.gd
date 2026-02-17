extends Area3D

# The specific item data (e.g., Fishing Rod, Apple, Ammo)
@export var item_data: ItemData

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

func _ready() -> void:
	# 1. Connect the signal via code (cleaner than using the Node tab)
	body_entered.connect(_on_body_entered)
	
	# 2. Update the visual mesh if data exists
	if item_data and item_data.ground_mesh:
		mesh_instance.mesh = item_data.ground_mesh

func _process(delta: float) -> void:
	# Optional: Rotate slowly to look like a "pickup"
	rotate_y(1.0 * delta)

func _on_body_entered(body: Node3D) -> void:
	# Check if the body is the player and has an inventory
	if body.has_method("add_to_inventory"):
		if item_data:
			body.add_to_inventory(item_data)
			queue_free() # Delete this object from the world
