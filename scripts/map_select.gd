extends StaticBody3D # The Chest in your 3D world
class_name map

func interact(player) -> void:
	if player.map_ui.visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	player.map_ui.visible = !player.map_ui.visible
	player.crosshair.visible = !player.crosshair.visible
