extends Node

class_name StateMachine


var current_state: State


func initialize(initial_state: State) -> void:

	current_state = initial_state

	current_state.enter()


func change_state(new_state: State) -> void:

	if current_state:

		current_state.exit()

	current_state = new_state

	current_state.enter()


func update(delta: float) -> void:

	if current_state:

		current_state.update(delta)


func physics_update(delta: float) -> void:

	if current_state:

		current_state.physics_update(delta)
