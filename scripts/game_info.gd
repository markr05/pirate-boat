extends Control

@onready var coin_label: Label = %CoinLabel 

func update_coins_display(amount: int):
	var coin_label = find_child("CoinLabel", true, false)
	coin_label.text = "Coins: %s" % amount
