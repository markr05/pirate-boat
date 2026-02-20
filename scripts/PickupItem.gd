extends Area3D

@export var item_data: ItemData
@onready var mesh_instance: MeshInstance3D = $MeshInstance3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# loads the correct meshes when the game starts
	if item_data and item_data.ground_mesh:
		mesh_instance.mesh = item_data.ground_mesh


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		body.add_to_inventory(item_data)
		queue_free()
		
func _process(delta: float) -> void:
	# Optional: Rotate slowly to look like a "pickup"
	rotate_y(1.0 * delta)	
