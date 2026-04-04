extends Control

@onready var coin_label: Label = %MarginContainer/CoinLabel
@onready var xp_label: Label = %MarginContainer/ForagingLvl
@onready var item_label: Label = %ItemNameMargin/ItemName
@onready var hp_bar: ProgressBar = $HpMargin/ProgressBar
@onready var stamina_bar: ProgressBar = $StaminaMargin/ProgressBar

var fade_tween: Tween
var item_label_default_y: float # Store the "home" spot here

func _ready():
	add_to_group("game_info")
	item_label.modulate.a = 0.0
	
	# Wait one frame so the UI Containers/Anchors set the final position
	await get_tree().process_frame 
	item_label_default_y = item_label.position.y

func update_coins_display(amount: int):
	if coin_label:
		coin_label.text = "Coins: %d" % amount

func update_levels_display(foraging_lvl: int, fishing_lvl: int):
	if xp_label:
		xp_label.text = "Foraging Level: %d\n Fishing Level: %d" % [foraging_lvl, fishing_lvl]

func update_item_display(item_data: ItemData):
	if fade_tween:
		fade_tween.kill()
	
	if not item_data:
		fade_tween = create_tween()
		fade_tween.tween_property(item_label, "modulate:a", 0.0, 0.2)
		return

	item_label.text = item_data.name
	
	# 1. Reset position to the "bottom" starting point
	item_label.position.y = item_label_default_y + 15
	
	fade_tween = create_tween()
	
	# 2. Start the SLIDE normally
	fade_tween.tween_property(item_label, "position:y", item_label_default_y, 0.15)
	
	# 3. Make the FADE happen at the SAME TIME as the slide
	fade_tween.parallel().tween_property(item_label, "modulate:a", 1.0, 0.15)
	
	# 4. Continue with the rest of the sequence
	fade_tween.tween_interval(1.0)
	fade_tween.tween_property(item_label, "modulate:a", 0.0, 0.5)
