extends StaticBody3D # The Chest in your 3D world

@export var inventory_size: int = 18
var inventory_slots: Array = []

func _ready():
	inventory_slots.resize(inventory_size)
	inventory_slots.fill(null)

func interact(player):
	player.open_external_inventory(self)
