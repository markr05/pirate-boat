extends Control
class_name InventoryController

var item_slots_count: int = 27
var inventory_slot_prefab: PackedScene = load("res://scenes/ui/slot.tscn")
@onready var inventory_grid: GridContainer = %GridContainer
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false

func _ready() -> void:
	var player = get_tree().get_first_node_in_group("player") 

	for i in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
		
		slot.parent_inventory = player # Now the slot knows it belongs to the Player
		
		slot.inventory_slot_id = i + 9
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		slot.on_item_double_clicked.connect(_on_item_double_clicked)
		slot.on_item_right_clicked.connect(_on_item_right_clicked)

func update_inventory_ui(inventory_data: Array):
	# 1. Get all the slot UI nodes we currently have
	var ui_slots = inventory_grid.get_children()
	
	# 2. Loop through the data sent by the player
	for i in range(inventory_data.size()):
		# Safety: Stop if we have more data than physical UI slots
		if i >= ui_slots.size(): 
			break
			
		var current_slot_ui = ui_slots[i]
		var data_entry = inventory_data[i]
		
		# 3. If there is an item in this data slot
		if data_entry != null:
			# Tell the Slot UI to show the item icon and quantity
			# (Assumes your Slot script has a 'display_item' function)
			current_slot_ui.display_item(data_entry["data"], data_entry["quantity"])
		else:
			# If the data is null, tell the Slot UI to clear its icon
			current_slot_ui.clear_slot()

func _on_item_swapped_on_slot(from_id: int, to_id: int):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var item_from = player.get_item_at_index(from_id)
	var item_to = player.get_item_at_index(to_id)

	if item_from and item_to:
		var data_from = item_from["data"]
		var data_to = item_to["data"]
		
		if data_from is LureData and data_to is RodData:
			_combine_lure_and_rod(player, from_id, to_id)
			return

	if player.has_method("handle_global_swap"):
		player.handle_global_swap(from_id, to_id)

func _combine_lure_and_rod(player, lure_id: int, rod_id: int):
	# Logic for your player/inventory script to handle the attachment
	# Example: rod_item.lure = lure_item; remove lure_item from inventory
	if player.has_method("attach_lure_to_rod"):
		player.attach_lure_to_rod(lure_id, rod_id)

		
func _on_item_double_clicked(slot_id: int):
	return
	
func _on_item_right_clicked(slot_id: int):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var item_entry = player.get_item_at_index(slot_id)
	if item_entry and item_entry["data"] is RodData:
		var rod = item_entry["data"]
		
		if rod.lure != null:
			if player.has_method("remove_lure_from_rod"):
				player.remove_lure_from_rod(slot_id)
			else:
				print("Player script missing remove_lure_from_rod method!")
