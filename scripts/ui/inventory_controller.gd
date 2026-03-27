extends Control
class_name InventoryController

# Inventory
var item_slots_count: int = 27
var inventory_slot_prefab: PackedScene = load("res://scenes/ui/slot.tscn")
@onready var inventory_grid: GridContainer = %GridContainer
var inventory_slots: Array[InventorySlot] = []
var inventory_full: bool = false

# Equipment
var equipment_slots: Array[InventorySlot] = []
var equipment_slots_count: int = 3
@onready var equipment_grid: GridContainer = %EquipmentGrid

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
	
	for i in equipment_slots_count:
		var slot = inventory_slot_prefab.instantiate() as InventorySlot
		equipment_grid.add_child(slot)
		equipment_slots.append(slot)
		
		slot.parent_inventory = player
		slot.inventory_slot_id = i + 36
		slot.on_item_swapped.connect(_on_item_swapped_on_slot)
		slot.on_item_double_clicked.connect(_on_item_double_clicked)
		slot.on_item_right_clicked.connect(_on_item_right_clicked)

func update_inventory_ui(inventory_data: Array):
	# 1. Get all slots from both grids into one list for easier iteration
	var all_ui_slots = inventory_slots + equipment_slots
	
	for ui_slot in all_ui_slots:
		var slot_id = ui_slot.inventory_slot_id
		
		# 2. Check if the player's data array actually has this index
		if slot_id < inventory_data.size():
			var data_entry = inventory_data[slot_id]
			
			if data_entry != null:
				ui_slot.display_item(data_entry["data"], data_entry["quantity"])
			else:
				ui_slot.clear_slot()
		else:
			ui_slot.clear_slot()



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
