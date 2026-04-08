extends ObjectInteract

# Drag the .tscn file you want to spawn into this slot in the Inspector
@export var replacement_scene: PackedScene

func interact(player) -> void:
	if not replacement_scene:
		push_warning("No replacement scene assigned to " + name)
		return

	# 1. Create the new object from the scene file
	var new_obj = replacement_scene.instantiate()

	# 2. Add it to the world. 
	# We add it to the PARENT of the current object so it stays in the level
	get_parent().add_child(new_obj)

	# 3. Move the new object to the exact spot of the current one
	if new_obj is Node3D:
		new_obj.global_transform = self.global_transform

	# 4. Optional: If the new object is also an ObjectInteract, 
	# you can trigger something on it immediately
	if new_obj.has_method("focus"):
		new_obj.focus()

	# 5. Delete the old object (the one the script is on)
	queue_free()
