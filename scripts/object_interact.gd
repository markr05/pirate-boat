extends StaticBody3D
class_name ObjectInteract

const OUTLINE_SHADER = preload("res://shaders/item_highlight.gdshader")

var is_focused: bool = false

@export var mesh_node: MeshInstance3D
@export var collision_node: CollisionShape3D


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
	pass

func _update_item_visuals():
	if mesh_node:
		var mat = ShaderMaterial.new()
		mat.shader = OUTLINE_SHADER
		mat.set_shader_parameter("outline_color", Color(1.0, 1.0, 1.0, 1.0)) 
		
		var initial_width = 5.0 if is_focused else 0.0
		mat.set_shader_parameter("outline_width", initial_width)
		
		mesh_node.material_overlay = mat
		
	if collision_node and mesh_node and mesh_node.mesh:
		# 1. Freeze the body immediately
		
		# 2. Generate the shape
		var new_shape = mesh_node.mesh.create_convex_shape(true, true)
		
		# 3. Use deferred (this is actually safer for the physics server)
		collision_node.set_deferred("shape", new_shape)
		
		# 4. THE FIX: Wait multiple frames. 
		# We need to give Terrain3D enough time to bake its collision floor.
		# Waiting 3 physics frames is usually the sweet spot for heavy plugins.
		for i in range(3):
			await get_tree().physics_frame

		
	elif not mesh_node.mesh:
		# SAFETY CHECK: If this prints in your console, your item is falling 
		# because it literally doesn't have a mesh loaded yet to build a shape from!
		push_warning(name + " tried to build collision, but has no mesh!")
