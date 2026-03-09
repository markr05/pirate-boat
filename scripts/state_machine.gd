class_name PlayerStateMachine extends Node

@export var initial_state: PlayerState
var current_state: PlayerState

func init(player: CharacterBody3D) -> void:
	for child in get_children():
		if child is PlayerState:
			child.player = player
			child.state_machine = self
			
	if initial_state:
		current_state = initial_state
		current_state.enter()

func process_physics(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func process_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

func transition_to(state_name: String) -> void:
	if not has_node(state_name):
		push_error("State %s does not exist" % state_name)
		return
		
	var new_state = get_node(state_name) as PlayerState
	if current_state == new_state:
		return
		
	if current_state:
		current_state.exit()
		
	current_state = new_state
	current_state.enter()
