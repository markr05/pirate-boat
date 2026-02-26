extends Node

signal fish_bit(fish_data)  # Tells the rod to make the bobber jiggle
signal fish_caught(fish_data)

@onready var fishing_rod = get_parent()

var is_waiting: bool = false
var bite_timer: float = 0.0

@export var fish_types: Array[ItemData] = []

func start_waiting():
	is_waiting = true
	bite_timer = randf_range(2.0, 4.0)

func _process(delta):
	if is_waiting:
		bite_timer -= delta
		if bite_timer <= 0:
			trigger_bite()

func calculate_chances():
	var lure: LureData = fishing_rod.rod.lure
	var bait_power: float = 0.0
	if lure != null:
		bait_power = lure.bait_power
	# uncommon chance is weird because it goes up then down
	var p: float = 0.0
	if bait_power > 50.0:
		p = -0.012 * (bait_power - 55)**2 + 58
	var uncommon_chance: float = 30.0 + (0.6 * bait_power) - p
	
	var rare_chance: float = 8.0 + (0.5 * bait_power)
	var legendary_chance: float = 2.0 + (0.3 * bait_power)
	
	var common_chance: float = max(0, 100.0 - rare_chance - legendary_chance - uncommon_chance)
	
	var weights = PackedFloat32Array([
		common_chance, 
		max(0, uncommon_chance), 
		max(0, rare_chance), 
		max(0, legendary_chance)
	])
	return weights
	
func trigger_bite():
	var weights = calculate_chances()
	is_waiting = false
	var chosen_fish = RandomNumberGenerator.new().rand_weighted(weights)
	fish_bit.emit(fish_types[chosen_fish]) # Signal the rod to jiggle

func reset():
	is_waiting = false
	bite_timer = 0.0
