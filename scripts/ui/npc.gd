extends StaticBody3D # The Chest in your 3D world
class_name NPC

@export var inventory_size: int = 9
var inventory_slots: Array = []
@export var starting_items: Array[ItemData] = [] # Drag items here in Inspector

func _ready():
	inventory_slots.resize(inventory_size)
	inventory_slots.fill(null)
	for item in starting_items:
		add_to_inventory(item, 1)

func interact(player):
	player.open_external_inventory(self)
	player.crosshair.visible = !player.crosshair.visible

func close_inventory(player):
	pass

func get_total_inventory_value() -> int:
	var total = 0
	
	for slot in inventory_slots:
		# Check if the slot dictionary exists and isn't null
		if slot != null and slot.has("data") and slot["data"] != null:
			var item_resource = slot["data"]
			var quantity = slot["quantity"]
			
			# Add (Price * Quantity) to the total
			total += item_resource.price * quantity
			
	return total

func add_to_inventory(item_data: ItemData, amount: int = 1) -> bool:
	# 1. Try to find an existing stack of this item
	for i in range(inventory_slots.size()):
		var slot = inventory_slots[i]
		if slot != null and slot["data"] == item_data:
			slot["quantity"] += amount
			return true

	# 2. If not found, find the first empty (null) slot
	for i in range(inventory_slots.size()):
		if inventory_slots[i] == null:
			inventory_slots[i] = {
				"data": item_data,
				"quantity": amount
			}
			return true

	# Inventory is full
	print("Chest is full!")
	return false
