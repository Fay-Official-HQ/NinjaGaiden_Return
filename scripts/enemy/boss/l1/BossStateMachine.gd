extends Node
class_name BossStateMachine

var current_state: BossState
var states: Dictionary = {}
var boss: Boss
var _deferred_start: bool = false

func _ready() -> void:
	await owner.ready
	boss = owner as Boss
	for child in get_children():
		if child is BossState:
			states[child.name.to_lower()] = child
			child.boss = boss
			child.state_machine = self
	if states.size() > 0 and not _deferred_start:
		_enter_first_state()

func defer_start() -> void:
	_deferred_start = true

func start() -> void:
	if states.size() > 0:
		_enter_first_state()

func _enter_first_state() -> void:
	var first = states.values()[0]
	current_state = first
	current_state.enter()

func change_state(new_state: BossState, msg: Dictionary = {}) -> void:
	if not new_state or current_state == new_state:
		return
	if current_state:
		current_state.exit()
	var from_name = String(current_state.name) if current_state else "无"
	print("【Boss状态机】", from_name, " → ", new_state.name)
	current_state = new_state
	current_state.enter(msg)

func change_state_by_name(state_name: String, msg: Dictionary = {}) -> void:
	var key = state_name.to_lower()
	if states.has(key):
		change_state(states[key], msg)

func update(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func physics_update(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)
