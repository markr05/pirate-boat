extends Node3D
class_name EquippableItem

var player_ref: CharacterBody3D

# Called when the item is spawned into the player's hand
func setup(player):
	player_ref = player

# Called when the player clicks
func primary_action():
	print("Used " + name)

# Called when the player right-clicks
func secondary_action(is_pressed: bool):
	pass

# Called when switching away from this item
func unequip():
	queue_free()
