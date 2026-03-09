class_name PlayerState extends Node

var player: CharacterBody3D
var state_machine: Node

# Called when the state machine enters this state
func enter() -> void:
	pass

# Called when the state machine exits this state
func exit() -> void:
	pass

# Equivalent to _physics_process
func physics_update(_delta: float) -> void:
	pass

# Equivalent to _unhandled_input
func handle_input(_event: InputEvent) -> void:
	pass
