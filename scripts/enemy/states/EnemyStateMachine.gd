# res://scripts/enemy/states/EnemyStateMachine.gd
extends Node

class_name EnemyStateMachine

@export var initial_state: EnemyState

var current_state: EnemyState
var states: Dictionary = {}

func _ready() -> void:
	await owner.ready
	
	for child in get_children():
		if child is EnemyState:
			states[child.name.to_lower()] = child
			child.enemy = owner as Enemy
			child.state_machine = self
	
	if initial_state:
		current_state = initial_state
	elif states.has("patrolstate"):
		initial_state = states["patrolstate"]
		current_state = initial_state
	
	if current_state:
		current_state.enter()

func change_state(new_state: EnemyState, msg: Dictionary = {}) -> void:
	if not new_state or current_state == new_state:
		return
	
	if current_state:
		current_state.exit()
	
	current_state = new_state
	current_state.enter(msg)

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
