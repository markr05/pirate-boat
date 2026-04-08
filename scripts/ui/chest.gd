extends StaticBody3D # The Chest in your 3D world

@export var inventory_size: int = 18
var inventory_slots: Array = []

func _ready():
	inventory_slots.resize(inventory_size)
	inventory_slots.fill(null)

func interact(player):
	player.open_external_inventory(self)
	player.crosshair.visible = false


func close_inventory(player):
	var total_value = get_total_inventory_value()
	if total_value > 0:
		player.coins += total_value
		print("Sold items for: ", total_value)
		inventory_slots.fill(null) # Empty the chest after payout

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
