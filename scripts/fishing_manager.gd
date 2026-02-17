extends Node

signal fish_bit  # Tells the rod to make the bobber jiggle
signal fish_caught(fish_data)

var is_waiting: bool = false
var bite_timer: float = 0.0

# Simple loot table
var fish_types = ["Bass", "Trout", "Salmon", "Old Boot"]

func start_waiting():
	is_waiting = true
	# Randomly wait between 3 and 8 seconds
	bite_timer = randf_range(3.0, 8.0)
	print("Manager: Waiting for a bite...")

func _process(delta):
	if is_waiting:
		bite_timer -= delta
		if bite_timer <= 0:
			trigger_bite()

func trigger_bite():
	is_waiting = false
	var chosen_fish = fish_types.pick_random()
	fish_bit.emit() # Signal the rod to jiggle
	print("Manager: A " + chosen_fish + " is on the line!")

func reset():
	is_waiting = false
	bite_timer = 0.0
