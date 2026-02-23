extends Node

signal fish_bit(fish_data)  # Tells the rod to make the bobber jiggle
signal fish_caught(fish_data)

var is_waiting: bool = false
var bite_timer: float = 0.0

# Simple loot table
@export var fish_types: Array[ItemData] = []

func start_waiting():
	is_waiting = true
	bite_timer = randf_range(2.0, 4.0)

func _process(delta):
	if is_waiting:
		bite_timer -= delta
		if bite_timer <= 0:
			trigger_bite()

func trigger_bite():
	is_waiting = false
	var chosen_fish = fish_types.pick_random()
	fish_bit.emit(chosen_fish) # Signal the rod to jiggle

func reset():
	is_waiting = false
	bite_timer = 0.0
