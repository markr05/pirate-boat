extends Control

# Use % for Scene Unique Names (Right-click Label -> Access as Unique Name)
@onready var coin_label: Label = %MarginContainer/CoinLabel 

func _ready():
	# Add to group so the player can find it during _ready
	add_to_group("game_info")

func update_coins_display(amount: int):
	if coin_label:
		coin_label.text = "Coins: %d" % amount
	else:
		# Fallback if the @onready hasn't fired yet or name is wrong
		var backup_label = find_child("CoinLabel", true, false)
		if backup_label:
			backup_label.text = "Coins: %d" % amount
