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
	if player and player.has_method("handle_global_swap"):
		player.handle_global_swap(from_id, to_id)
		
func _on_item_double_clicked(slot_id: int):
	return
	
func _on_item_right_clicked(slot_id: int):
	return
