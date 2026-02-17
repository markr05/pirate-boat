extends GridContainer

@export var slot_scene: PackedScene 
@export var columns_count: int = 5
@export var total_slots: int = 15

func _ready():
	setup_grid(columns_count, total_slots)

func setup_grid(cols: int, count: int, display_numbers: bool = false):
	columns = cols
	# Clear existing slots
	for child in get_children():
		child.queue_free()
		
	for i in range(count):
		var new_slot = slot_scene.instantiate()
		add_child(new_slot)
		
		# Find the KeyLabel (the hotkey number 1-9)
		var key_label = new_slot.get_node_or_null("KeyLabel")
		
		if key_label:
			if display_numbers:
				key_label.text = str(i + 1)
				key_label.show()
			else:
				key_label.hide() # Hide it for chests!

## NEW FUNCTION: Put an item in a specific slot index (0 to total_slots - 1)
func set_item_at_slot(index: int, item_data: ItemData):
	var slots = get_children()
	
	if index >= 0 and index < slots.size():
		var target_slot = slots[index]
		
		# We must go deeper into the hierarchy you built:
		# Panel7 (target_slot) -> MarginContainer -> TextureRect
		var icon_rect = target_slot.get_node_or_null("MarginContainer/TextureRect")
		
		if icon_rect:
			if item_data != null and item_data.icon != null:
				icon_rect.texture = item_data.icon
				icon_rect.show()
				print("Successfully set texture for: ", item_data.name)
			else:
				icon_rect.texture = null
				icon_rect.hide()
		else:
			# This will print if the path "MarginContainer/TextureRect" is wrong
			print("Could not find TextureRect in slot ", index)
	else:
		print("Error: Slot index ", index, " is out of bounds!")
