class_name InventoryComponent extends Node

signal inventory_updated(slots: Array)
signal active_item_changed(item_data: ItemData)
signal equip_requested(item_data: ItemData) # Tells the player to spawn the 3D model

const MAX_SLOTS = 45
var inventory_slots: Array = [] 
var current_slot: int = 0

@export var world_item_scene: PackedScene
@export var drop_origin: Node3D # Assign the Player's 'Head' node to this in the Inspector!

# --- UI REFERENCES ---
# Because this is a child of the Player scene, it can still use Scene Unique Nodes (%)
@onready var inventory_controller: Node = %InventoryController/CanvasLayer/InventoryUI
@onready var hotbar_controller: Node = %InventoryController/CanvasLayer/HotbarUI

func _ready() -> void:
	inventory_slots.resize(MAX_SLOTS)
	inventory_slots.fill(null)
	_refresh_inventory()

# --- CORE INVENTORY LOGIC ---
func add_to_inventory(item: ItemData):
	var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
	var external_inventory = external_ui.current_inventory if (external_ui and external_ui.visible) else null

	# 1. Check for existing stacks (Player + Chest)
	if item.stackable:
		for slot in inventory_slots:
			if slot and slot["data"] == item and slot["quantity"] < item.max_stack_size:
				slot["quantity"] += 1
				_refresh_inventory()
				return 
		
		if external_inventory:
			for slot in external_inventory.inventory_slots:
				if slot and slot["data"] == item and slot["quantity"] < item.max_stack_size:
					slot["quantity"] += 1
					external_ui.update_ui(external_inventory.inventory_slots)
					return

	# 2. Find empty slot in Player first
	var empty_slot = find_first_empty_slot()
	if empty_slot != -1:
		inventory_slots[empty_slot] = { "data": item, "quantity": 1 }
		_refresh_inventory()
		return

	# 3. If Player is full, find empty slot in Chest
	if external_inventory:
		for i in range(external_inventory.inventory_slots.size()):
			if external_inventory.inventory_slots[i] == null:
				external_inventory.inventory_slots[i] = { "data": item, "quantity": 1 }
				external_ui.update_ui(external_inventory.inventory_slots)
				return
				
	print("Everything (including the chest) is full!")

func _refresh_inventory():
	var player = get_parent()
	if not player: return
	
	var equipment_ids = [36, 37, 38]
	player.speed_multiplier = 1.0
	inventory_updated.emit(inventory_slots)
	
	if hotbar_controller and hotbar_controller.has_method("update_inventory_ui"):
		hotbar_controller.update_inventory_ui(inventory_slots.slice(0, 9))
	
	if inventory_controller and inventory_controller.has_method("update_inventory_ui"):
		inventory_controller.update_inventory_ui(inventory_slots)
		
	for id in equipment_ids:
		var slot = get_item_at_index(id)
		if slot and slot["data"] is AccessoryData:
			var data = slot["data"] as AccessoryData
			
			# 3. Apply the stats found on the Resource
			player.speed_multiplier += data.speed
			player.strength += data.strength
			player.defense += data.defense

func select_slot(index: int, is_fishing: bool = false):
	# Prevent switching if busy (Player will pass in `is_fishing` from the current_tool)
	if is_fishing: 
		return
		
	current_slot = index
	
	if hotbar_controller and hotbar_controller.has_method("set_active_slot"): 
		hotbar_controller.set_active_slot(index)
	
	if index >= 0 and inventory_slots[index] != null:
		var item_to_equip = inventory_slots[index]["data"]
		equip_requested.emit(item_to_equip) # Tell player to spawn it
		active_item_changed.emit(item_to_equip) # Update UI
	else:
		equip_requested.emit(null) # Tell player to unequip
		active_item_changed.emit(null)

func change_active_slot(direction: int, is_fishing: bool = false) -> void:
	if is_fishing: return
	var new_index = posmod(current_slot + direction, 9)
	select_slot(new_index, false)
	
func get_active_item() -> ItemData:
	# 1. Check if the current slot has anything in it
	var slot_data = inventory_slots[current_slot]
	
	if slot_data != null and slot_data.has("data"):
		# 2. Return just the ItemData resource (the shovel, apple, etc.)
		return slot_data["data"]
		
	return null
	
func drop_current_item():
	print("Drop requested for slot: ", current_slot)
	var slot_data = inventory_slots[current_slot]
	
	if slot_data == null: 
		print("Failed: Slot is empty")
		return
	if not world_item_scene: 
		print("Failed: world_item_scene not assigned")
		return
	if not drop_origin: 
		print("Failed: drop_origin (Head node) not assigned")
		return

	print("Dropping: ", slot_data["data"].resource_name)
	#var slot_data = inventory_slots[current_slot]
	if slot_data == null or not world_item_scene or not drop_origin: return
	
	var dropped_item = world_item_scene.instantiate()
	dropped_item.item_data = slot_data["data"]
	
	# Add to the main scene tree, not the player!
	drop_origin.get_tree().current_scene.add_child(dropped_item)
	
	# Calculate toss physics based on the drop_origin (Player's Head)
	dropped_item.global_position = drop_origin.global_position + (-drop_origin.global_transform.basis.z * 1.5)
	var throw_direction = -drop_origin.global_transform.basis.z + Vector3(0, 0.5, 0)
	dropped_item.apply_central_impulse(throw_direction * 5.0)

	if slot_data["quantity"] > 1:
		slot_data["quantity"] -= 1
	else:
		inventory_slots[current_slot] = null
		equip_requested.emit(null)
		active_item_changed.emit(null)

	_refresh_inventory()

# --- UTILS & CRAFTING / FISHING LOGIC ---
func find_first_empty_slot() -> int:
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			return i
	return -1

func get_item_at_index(id: int):
	if id >= 0 and id < inventory_slots.size():
		return inventory_slots[id]
	return null

func handle_global_swap(from_id: int, to_id: int):
	var external_ui = get_tree().get_first_node_in_group("external_inventory_ui")
	var chest = external_ui.current_inventory if (external_ui and external_ui.visible) else null

	var chest_offset = 45

	var get_data = func(id: int):
		if id < chest_offset: 
			return inventory_slots[id]
		elif chest: 
			return chest.inventory_slots[id - chest_offset]
		return null

	var set_data = func(id: int, data):
		if id < chest_offset: 
			inventory_slots[id] = data
		elif chest: 
			chest.inventory_slots[id - chest_offset] = data

	var from_data = get_data.call(from_id)
	var to_data = get_data.call(to_id)
	
	set_data.call(from_id, to_data)
	set_data.call(to_id, from_data)
	
	_refresh_inventory()
	
	if chest: 
		external_ui.update_ui(chest.inventory_slots)
	
	# Sync the 3D model if we swapped the item currently in our hand
	if current_slot == from_id or current_slot == to_id:
		select_slot(current_slot)

func set_item_at_index(index: int, item_data: ItemData):
	if index >= 0 and index < inventory_slots.size():
		# 1. Update the actual data array
		inventory_slots[index] = {
			"data": item_data,
			"quantity": 1
		}
		
		active_item_changed.emit(item_data) 
		
		_refresh_inventory()

func attach_lure_to_rod(lure_id: int, rod_id: int):
	var lure_slot = get_item_at_index(lure_id) as Dictionary
	var rod_slot = get_item_at_index(rod_id) as Dictionary
	
	if lure_slot and rod_slot:
		var lure_data = lure_slot["data"]
		var rod_data = rod_slot["data"]
		
		# NOTE: Make sure LureData and RodData are accessible classes here
		if lure_data and rod_data and "lure" in rod_data:
			if not rod_data.resource_path.is_empty(): 
				rod_data = rod_data.duplicate()
				inventory_slots[rod_id]["data"] = rod_data
			
			rod_data.lure = lure_data
			inventory_slots[lure_id] = null
			
			_refresh_inventory()
			if current_slot == rod_id: select_slot(rod_id)
			print("Successfully attached lure")

func remove_lure_from_rod(rod_slot_id: int):
	var item_entry = get_item_at_index(rod_slot_id) as Dictionary
	if item_entry and "lure" in item_entry["data"]:
		var rod_data = item_entry["data"]
		if rod_data.lure != null:
			var empty_slot = find_first_empty_slot()
			if empty_slot != -1:
				var lure_to_pop = rod_data.lure
				rod_data.lure = null
				inventory_slots[empty_slot] = { "data": lure_to_pop, "quantity": 1 }
				
				_refresh_inventory()
				if current_slot == rod_slot_id: select_slot(rod_slot_id)
			else:
				print("Inventory full! Cannot remove lure.")
