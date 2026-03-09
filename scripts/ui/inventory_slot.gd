extends Control
class_name InventorySlot

@onready var icon_rect: TextureRect = $MarginContainer/Icon 
@onready var quantity_label: Label = $MarginContainer/Icon/Label
@onready var highlight_rect: ColorRect = $Highlight
@onready var attachment_rect: TextureRect = $MarginContainer/Icon/Attachment

# --- DATA VARIABLES ---
var inventory_slot_id: int = -1
var slot_filled: bool = false
var slot_data: ItemData = null 
var current_quantity: int = 0  
var parent_inventory: Node = null 

signal on_item_swapped(from_slot: int, to_slot: int)
signal on_item_double_clicked(slot_id: int)
signal on_item_right_clicked(slot_id: int)

func _ready():
	mouse_entered.connect(_on_mouse_entered)
	
func _on_mouse_entered():
	# Useful for debugging parent assignment
	if parent_inventory == null:
		print("Slot ID: ", inventory_slot_id, " | Parent: NULL")
	else:
		# Using get_script().get_global_name() helps identify 'NPC' vs 'Player' better
		print("Slot ID: ", inventory_slot_id, " | Parent: ", parent_inventory.get_class())

func display_item(item_data: ItemData, amount: int):
	slot_data = item_data
	current_quantity = amount
	if slot_data != null:
		slot_filled = true
		icon_rect.texture = item_data.icon
		icon_rect.modulate.a = 1.0 # Reset opacity
		if slot_data is RodData and slot_data.lure != null:
			attachment_rect.texture = slot_data.lure.icon
			attachment_rect.show()
		else:
			attachment_rect.hide()
		if quantity_label:
			quantity_label.text = str(amount)
			quantity_label.visible = (amount > 1)
	else:
		clear_slot()

func clear_slot():
	slot_data = null
	current_quantity = 0
	slot_filled = false
	icon_rect.texture = null
	attachment_rect.hide()
	if quantity_label: quantity_label.hide()

# --- DRAG AND DROP SYSTEM ---
func _get_drag_data(_at_position: Vector2) -> Variant:
	if not slot_filled:
		return null
		
	var drag_data = {
		"data": slot_data,
		"quantity": current_quantity,
		"origin_node": parent_inventory,
		"origin_slot_id": inventory_slot_id
	}
	
	# 1. Create a Container to act as the "Master Layer"
	var preview_container = Control.new()
	preview_container.top_level = true
	preview_container.z_index = 100 # Force it to the very front
	preview_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	# 2. Create the actual Icon
	var preview_icon = TextureRect.new()
	preview_icon.texture = icon_rect.texture
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.size = Vector2(60, 60) # Make it slightly larger so it's obvious
	
	# 3. Center the icon on the mouse cursor
	preview_icon.position = -preview_icon.size / 2
	
	# 4. Assemble and Set
	preview_container.add_child(preview_icon)
	set_drag_preview(preview_container)
	
	# Shop logic (optional ghosting)
	if not parent_inventory is NPC:
		icon_rect.modulate.a = 0.5
	
	return drag_data

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_DRAG_BEGIN:
			# 1. Get the data currently being dragged by the mouse
			var drag_data = get_viewport().gui_get_drag_data()
			
			# 2. Check if the data is a dictionary and if it came from THIS slot
			if drag_data is Dictionary and drag_data.has("origin_slot_id"):
				if drag_data["origin_slot_id"] == inventory_slot_id:
					# Only fade if it's NOT an NPC (we want shops to stay bright)
					if not parent_inventory is NPC:
						icon_rect.modulate.a = 0.5
						
		NOTIFICATION_DRAG_END:
			# 3. Always reset the alpha when any drag ends, successful or not
			if is_instance_valid(icon_rect):
				icon_rect.modulate.a = 1.0

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	# Check if we are dragging a valid inventory item dictionary
	return data is Dictionary and data.has("data")

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	var item_data = data["data"]
	var quantity = data["quantity"]
	var total_cost = item_data.price * quantity
	
	# 1. Handle Purchase (From NPC to Player)
	if data["origin_node"] is NPC and parent_inventory is Player:
		if parent_inventory.coins >= total_cost:
			parent_inventory.coins -= total_cost
			
			if parent_inventory.has_method("handle_global_swap"):
				parent_inventory.handle_global_swap(-1, inventory_slot_id, item_data)
				
				# --- ADD THIS LINE TO SHOW THE ICON IMMEDIATELY ---
				display_item(item_data, 1) 
				# --------------------------------------------------
			
			print("Purchased: ", item_data.name, " exactly at slot ", inventory_slot_id)
		return

	# 2. Normal Swap (Internal movement)
	on_item_swapped.emit(data["origin_slot_id"], inventory_slot_id)

# --- UTILITY & INPUT ---

func set_highlight(is_active: bool):
	if highlight_rect: highlight_rect.visible = is_active

func _gui_input(event: InputEvent) -> void:
	if not slot_filled: return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			on_item_double_clicked.emit(inventory_slot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			on_item_right_clicked.emit(inventory_slot_id)

func _make_custom_tooltip(_for_text: String) -> Control:
	if not slot_filled:
		return null
	
	# Load your custom tooltip scene
	var tooltip_scene = preload("res://scenes/ui/ItemToolTip.tscn")
	var tooltip = tooltip_scene.instantiate()
	
	# Find the labels in your tooltip scene and set the text
	# Use get_node or %UniqueNames if you set them up in the scene
	var name_label = tooltip.find_child("NameLabel")
	var price_label = tooltip.find_child("PriceLabel")
	
	if name_label:
		name_label.text = slot_data.name
		
	if price_label:
		# Only show price if it's an NPC/Shop item, or always show it!
		price_label.text = "Price: " + str(slot_data.price) + " Coins"
		
		# Optional: Turn text red if the player can't afford it
		var player = get_tree().get_first_node_in_group("player")
		if player and player.coins < slot_data.price and parent_inventory is NPC:
			price_label.modulate = Color.RED

	return tooltip
