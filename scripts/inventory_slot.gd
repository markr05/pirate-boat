extends Control
class_name InventorySlot

@onready var icon_rect: TextureRect = $MarginContainer/Icon 
@onready var quantity_label: Label = $MarginContainer/Icon/Label
@onready var highlight_rect: ColorRect = $Highlight

var inventory_slot_id: int = -1
var slot_filled: bool = false
var slot_data: ItemData # Static data (icon, name, max stack)

signal on_item_swapped(from_slot: int, to_slot: int)
signal on_item_double_clicked(slot_id: int)
signal on_item_right_clicked(slot_id: int)

# The Controller calls this and passes the quantity separately from the item
func display_item(item_data: ItemData, amount: int):
	slot_data = item_data
	
	if slot_data != null:
		slot_filled = true
		icon_rect.texture = item_data.icon
		
		# Handle the Quantity Label
		if quantity_label:
			# Only show text if stack is greater than 1
			if amount > 1:
				quantity_label.text = str(amount)
				quantity_label.show()
			else:
				quantity_label.hide()
	else:
		clear_slot()

func clear_slot():
	slot_data = null
	slot_filled = false
	if icon_rect:
		icon_rect.texture = null
	if quantity_label:
		quantity_label.hide()

func set_highlight(is_active: bool):
	if highlight_rect:
		highlight_rect.visible = is_active

# --- DRAG AND DROP ---

func _get_drag_data(_at_position: Vector2) -> Variant:
	if slot_filled:
		var preview = icon_rect.duplicate()
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.size = icon_rect.size
		preview.pivot_offset = icon_rect.size / 2.0
		preview.texture = icon_rect.texture
		set_drag_preview(preview)
		return inventory_slot_id
	return null

func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_INT

func _drop_data(_at_position: Vector2, data: Variant) -> void:
	on_item_swapped.emit(data, inventory_slot_id)

# --- INPUTS ---

func _gui_input(event: InputEvent) -> void:
	if not slot_filled:
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
			on_item_double_clicked.emit(inventory_slot_id)
		elif event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			on_item_right_clicked.emit(inventory_slot_id)
