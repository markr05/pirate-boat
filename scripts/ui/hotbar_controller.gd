extends Control
class_name HotbarController

var item_slots_count: int = 9 # Only 9 slots for the hotbar
var inventory_slot_prefab: PackedScene = load("res://scenes/ui/slot.tscn")
var current_active_index: int = 0


@onready var inventory_grid: GridContainer = %HotbarGrid 
var inventory_slots: Array[InventorySlot] = []

func _ready() -> void:
	for i in item_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		inventory_grid.add_child(slot)
		inventory_slots.append(slot)
		
		slot.inventory_slot_id = i
		if slot.has_method("set_key_text"):
			slot.set_key_text(str(i + 1))
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		slot.on_item_double_clicked.connect(_on_item_double_clicked)
		slot.on_item_right_clicked.connect(_on_item_right_clicked)


func update_inventory_ui(inventory_data: Array):
	var ui_slots = inventory_grid.get_children()
	
	for i in range(inventory_data.size()):
		if i >= ui_slots.size(): 
			break
			
		var current_slot_ui = ui_slots[i]
		var data_entry = inventory_data[i]
		
		if data_entry != null:
			current_slot_ui.display_item(data_entry["data"], data_entry["quantity"])
		else:
			current_slot_ui.clear_slot()

			
func set_active_slot(index: int):
	current_active_index = index
	var ui_slots = inventory_grid.get_children()
	
	# Loop through all 9 slots in the hotbar
	for i in range(ui_slots.size()):
		var slot_ui = ui_slots[i]
		
		if slot_ui.has_method("set_highlight"):
			# If the loop index matches the selected index, turn it ON (true)
			# Otherwise, turn it OFF (false)
			if i == current_active_index:
				slot_ui.set_highlight(true)
			else:
				slot_ui.set_highlight(false)

func _on_item_swapped_on_slot(from_id: int, to_id: int):
	var player = get_tree().get_first_node_in_group("player")
	if not player: return

	var item_from = player.get_item_at_index(from_id)
	var item_to = player.get_item_at_index(to_id)

	if item_from and item_to:
		var data_from = item_from["data"]
		var data_to = item_to["data"]
		
		# DEBUG PRINTS - Watch your output console
		print("Checking interaction: ", data_from.resource_path, " -> ", data_to.resource_path)

		if data_from is LureData and data_to is RodData:
			print("Lure detected! Attaching to rod...")
			_combine_lure_and_rod(player, from_id, to_id)
			return # This MUST trigger to stop the swap
		else:
			print("Logic failed: From is Lure? ", data_from is LureData, " To is Rod? ", data_to is RodData)

	# If we reach here, a normal swap happens
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
