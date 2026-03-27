extends RigidBody3D

const OUTLINE_SHADER = preload("res://shaders/item_highlight.gdshader")

var is_focused: bool = false

@export var mesh_node: MeshInstance3D
@export var collision_node: CollisionShape3D
@export var xp_value: float = 0.0
@export var xp_type: String = "Foraging"

@export var item_data: Resource:
	set(value):
		item_data = value
		if is_inside_tree():
			_update_item_visuals()

func _ready() -> void:
	_update_item_visuals()

func focus():
	is_focused = true
	_update_outline()

func unfocused():
	is_focused = false
	_update_outline()

func _update_outline():
	if mesh_node and mesh_node.material_overlay:
		var width = 5.0 if is_focused else 0.0
		mesh_node.material_overlay.set_shader_parameter("outline_width", width)

func interact(player) -> void:
	if item_data:
		var doubled = RandomNumberGenerator.new().randf_range(0.0, 1.0)
		# no double xp right now
		if doubled <= player.double_forage_chance:
			player.add_to_inventory(item_data)
		player.add_to_inventory(item_data)
		player.update_xp(xp_type, xp_value)
		queue_free()

func _update_item_visuals():
	if not item_data or not item_data.get("ground_mesh"):
		return

	if mesh_node:
		mesh_node.mesh = item_data.ground_mesh
		
		var mat = ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0)) 
		
		var initial_width = 5.0 if is_focused else 0.0
		mat.set_shader_parameter("outline_width", initial_width)
		
		mesh_node.material_overlay = mat
		
	if collision_node:
		var new_shape = item_data.ground_mesh.create_convex_shape()
		collision_node.set_deferred("shape", new_shape)
