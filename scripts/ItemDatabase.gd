extends Node

# This dictionary maps a String Name to the actual ItemData Resource
var items: Dictionary = {}

func _ready() -> void:
	# Load all items from your folder once when the game starts
	var path = "res://items/item_files/fish/"
	var dir = DirAccess.open(path)
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var item = load(path + file_name)
				if item is ItemData:
					# Store it by its resource name (e.g., "Salmon")
					items[item.name.to_lower()] = item
			file_name = dir.get_next()

func get_item_by_name(item_name: String) -> ItemData:
	var key = item_name.to_lower()
	if items.has(key):
		return items[key]
	push_error("ItemDb: Could not find item named: ", item_name)
	return null
