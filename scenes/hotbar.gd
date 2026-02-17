extends GridContainer

@export var total_slots: int = 9
@export var slot_scene: PackedScene 

# --- SETTINGS ---
@export var show_numbers: bool = true  # Toggle 1-9 numbers
@export var selected_color: Color = Color(1.2, 1.2, 1.2, 1.0) 
@export var unselected_color: Color = Color(1.0, 1.0, 1.0, 1.0)

var current_selection: int = 0

func _ready():
	# 1. Clear old placeholders
	for child in get_children():
		child.queue_free()
			
	# 2. Create new slots
	if slot_scene:
		for i in range(total_slots):
			var new_slot = slot_scene.instantiate()
			add_child(new_slot)
			
			# --- SETUP SLOT NUMBERS (1-9) ---
			if show_numbers:
				# Look for the specific "KeyLabel" we created earlier
				var key_label = new_slot.get_node_or_null("KeyLabel")
				
				# Fallback: If KeyLabel is missing, check generic Label
				# (But be careful, this might grab the quantity label!)
				if key_label == null: key_label = new_slot.get_node_or_null("Label")
				
				if key_label:
					key_label.text = str(i + 1)
					key_label.show()
			else:
				# Hide the number if the setting is off
				var key_label = new_slot.get_node_or_null("KeyLabel")
				if key_label: key_label.hide()

	# 3. Select the first slot by default
	set_active_slot(0)

# --- SELECTION LOGIC (Handles Colors Only) ---
func set_active_slot(index: int):
	current_selection = index
	
	for i in range(get_child_count()):
		var slot = get_child(i)
		
		# Find the background panel to colorize
		var panel = _find_node_by_class(slot, "Panel") 
		var target_visual = panel if panel else slot
		
		if i == index:
			target_visual.modulate = selected_color # Highlight
		else:
			target_visual.modulate = unselected_color # Normal

# --- UPDATE LOGIC (Handles Icons & Quantity) ---
func update_hotbar_ui(inventory_slots: Array):
	for i in range(total_slots):
		if i < inventory_slots.size() and inventory_slots[i] != null:
			set_item_at_slot(i, inventory_slots[i]["data"], inventory_slots[i]["quantity"])
		else:
			set_item_at_slot(i, null, 0)

func set_item_at_slot(index: int, item_data: ItemData, quantity: int):
	if index >= get_child_count(): return
	var slot = get_child(index)
	
	# FIND NODES recursively
	var icon_node = _find_node_by_class(slot, "TextureRect")
	
	# SPECIFICALLY look for the Quantity Label by name first to avoid grabbing KeyLabel
	var label_node = slot.get_node_or_null("Label")
	if label_node == null:
		# Fallback to searching if not named "Label" exactly
		label_node = _find_node_by_class(slot, "Label")

	# UPDATE VISUALS
	if item_data:
		# 1. Update Icon
		if icon_node:
			icon_node.texture = item_data.icon
			icon_node.visible = true
		
		# 2. Update Quantity (Only show if > 1)
		if label_node:
			if quantity > 1:
				label_node.text = str(quantity)
				label_node.visible = true
			else:
				label_node.text = "" # Clear text for safety
				label_node.visible = false
	else:
		# Clear Slot (No Item)
		if icon_node: icon_node.visible = false
		if label_node: label_node.visible = false
	

# --- HELPER: Finds nodes deep in the tree ---
func _find_node_by_class(root: Node, class_type: String) -> Node:
	if root.is_class(class_type):
		return root
	
	for child in root.get_children():
		var found = _find_node_by_class(child, class_type)
		if found:
			return found
			
	return null
