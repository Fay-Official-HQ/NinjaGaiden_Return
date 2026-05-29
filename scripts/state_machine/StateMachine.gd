extends Node
class_name StateMachine

@export var initial_state: State
var current_state: State

func _ready():
	for child in get_children():
		if child is State:
			child.player = get_parent()
			child.state_machine = self
	change_state(initial_state)

func change_state(new_state: State):
	if current_state:
		current_state.exit()
	current_state = new_state
	current_state.enter()

func _process(delta):
	if current_state:
		current_state.update(delta)

func _physics_process(delta):
	if current_state:
		current_state.physics_update(delta)

func _input(event):
	if current_state:
		current_state.handle_input(event)
