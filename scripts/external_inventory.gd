extends Control
class_name ExternalInventoryUI

var slot_prefab = preload("res://scenes/slot.tscn")
@onready var grid = $Panel/MarginContainer/GridContainer

var current_chest = null

func open_container(chest_object):
	if chest_object == null:
		return
		
	current_chest = chest_object
	
	# 1. Clear old slots IMMEDIATELY
	for child in grid.get_children():
		grid.remove_child(child) # Physically remove it so get_children() is empty
		child.queue_free() # Then tell it to delete
	
	# 2. Instantiate and Fill in one go
	for i in range(chest_object.inventory_size):
		var slot = slot_prefab.instantiate()
		grid.add_child(slot)
		
		# Assign Global ID
		slot.inventory_slot_id = i + 36
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		
		# FILL THE SLOT IMMEDIATELY
		var data_entry = chest_object.inventory_slots[i]
		if data_entry != null:
			slot.display_item(data_entry["data"], data_entry["quantity"])
		else:
			slot.clear_slot()
	
	self.show()
	get_parent().visible = true
	
func update_ui(data: Array):
	var ui_slots = grid.get_children()
	for i in range(data.size()):
		if i < ui_slots.size():
			if data[i] != null:
				ui_slots[i].display_item(data[i]["data"], data[i]["quantity"])
			else:
				ui_slots[i].clear_slot()

# --- NEW DRAGGING FUNCTIONALITY ---

func _on_item_swapped_on_slot(from_id: int, to_id: int):
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("handle_global_swap"):
		player.handle_global_swap(from_id, to_id)
