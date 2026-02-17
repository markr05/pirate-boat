extends Node3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	var t = Time.get_ticks_msec() / 1000.0
	
	# 1. Update the Ocean Shader
	# Make sure to point this to your actual Ocean mesh node
	$Ocean/ocean_mesh.get_active_material(0).set_shader_parameter("sync_time", t)
	
	# 2. Update the Bobber (if it exists)
	var bobber = get_node_or_null("Bobber")
	if bobber:
		bobber.current_time = t
