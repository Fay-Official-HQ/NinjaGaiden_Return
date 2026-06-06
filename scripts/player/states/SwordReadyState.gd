extends State

class_name SwordReadyState

@export var input_window_time: float = 0.1

var _window_timer: float = 0.0
var _in_window: bool = false
var _pending_dir: String = ""
var _dir_sent: bool = false

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	_start_window()
	if player.is_on_floor():
		player.animation.play("sword_ready")
	else:
		player.animation.play("fall")

func update(delta: float) -> void:
	if not Input.is_action_pressed("special_move"):
		_in_window = false
		_cancel_to_neutral()
		return

	if _dir_sent:
		return

	if _in_window:
		_window_timer -= delta
		_collect_direction()
		if _window_timer <= 0.0:
			_in_window = false
			_execute_if_direction()
		return

	_check_and_execute_direct()

func physics_update(_delta: float) -> void:
	_keep_stance()

func _start_window() -> void:
	_window_timer = input_window_time
	_in_window = true
	_pending_dir = ""
	_dir_sent = false

func _collect_direction() -> void:
	if Input.is_action_pressed("nav_up"):
		_pending_dir = "up"
	elif Input.is_action_pressed("nav_down"):
		_pending_dir = "down"
	elif Input.is_action_pressed("nav_right"):
		_pending_dir = "right"
	elif Input.is_action_pressed("nav_left"):
		_pending_dir = "left"

func _execute_if_direction() -> void:
	if _pending_dir != "":
		_dir_sent = true
		_do_sword(_pending_dir)

func _check_and_execute_direct() -> void:
	var dir = _get_direct_dir()
	if dir != "":
		_dir_sent = true
		_do_sword(dir)

func _get_direct_dir() -> String:
	if Input.is_action_just_pressed("nav_up"):
		return "up"
	if Input.is_action_just_pressed("nav_down"):
		return "down"
	var dir = player.input.move_direction
	if dir != 0:
		return "right" if dir > 0 else "left"
	return ""

func _do_sword(dir: String) -> void:
	var is_facing_right = player.facing_direction > 0
	match dir:
		"up":
			state_machine.change_state(state_machine.get_node("SwordUppercutState"))
		"down":
			if not player.is_on_floor():
				state_machine.change_state(state_machine.get_node("SwordDownslashState"))
		"right":
			state_machine.change_state(state_machine.get_node("SwordDashState") if is_facing_right else state_machine.get_node("SwordSpinState"))
		"left":
			state_machine.change_state(state_machine.get_node("SwordSpinState") if is_facing_right else state_machine.get_node("SwordDashState"))

func _cancel_to_neutral() -> void:
	if player.input.move_direction != 0:
		state_machine.change_state(player.run_state)
	else:
		state_machine.change_state(player.idle_state)

func _keep_stance() -> void:
	if not player.is_on_floor():
		player.movement.stop()
		player.move_and_slide()
		return
	player.movement.stop()
	player.move_and_slide()
