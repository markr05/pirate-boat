extends CanvasLayer

signal slot_selected(slot_index: int) # Add this!

const MAX_SLOTS = 9

@onready var grid = $ColorRect/GridContainer
var current_slot_index = 0

func _ready():
	for i in range(MAX_SLOTS):
		create_slot()
	update_selection()

func _input(event):
	for i in range(1, 10):
		if event.is_action_pressed("slot_" + str(i)):
			current_slot_index = i - 1
			update_selection()
			slot_selected.emit(current_slot_index)

func create_slot():
	var slot = ColorRect.new()
	slot.custom_minimum_size = Vector2(64, 64)
	slot.color = Color(0, 0, 0, 0.5)
	
	var center = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var icon = TextureRect.new()
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(50, 50)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var label = Label.new()
	label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	label.position = Vector2(-16, -24)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	
	center.add_child(icon)
	slot.add_child(center)
	slot.add_child(label)
	grid.add_child(slot)

func update_selection():
	var slots = grid.get_children()
	for i in range(slots.size()):
		var slot = slots[i]
		if i == current_slot_index:
			slot.color = Color(1, 1, 1, 0.5)
		else:
			slot.color = Color(0, 0, 0, 0.5)

func update_view(items: Array[ItemData]):
	var counts = {}
	for item in items:
		if item.name in counts:
			counts[item.name]["count"] += 1
		else:
			counts[item.name] = {"data": item, "count": 1}
	
	var unique_items = counts.values()
	var slots = grid.get_children()
	
	for i in range(MAX_SLOTS):
		var slot = slots[i]
		var icon = slot.get_child(0).get_child(0) 
		var label = slot.get_child(1)
		
		if i < unique_items.size():
			var info = unique_items[i]
			icon.texture = info["data"].icon
			icon.visible = true
			if info["count"] > 1:
				label.text = str(info["count"])
			else:
				label.text = ""
		else:
			icon.texture = null
			icon.visible = false
			label.text = ""
	
	slot_selected.emit(current_slot_index)

func get_selected_item(all_items: Array[ItemData]) -> ItemData:
	var unique_items = []
	var seen_names = []
	for item in all_items:
		if item.name not in seen_names:
			unique_items.append(item)
			seen_names.append(item.name)
	
	if current_slot_index < unique_items.size():
		return unique_items[current_slot_index]
	else:
		return null
