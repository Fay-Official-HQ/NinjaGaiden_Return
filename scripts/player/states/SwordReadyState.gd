extends State

class_name SwordReadyState

# 进入时记录的已按住方向（用于阻止失败弹回后立即重触发）
var _ignore_dir: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	_ignore_dir = player.input.move_direction
	if player.is_on_floor():
		player.animation.play("sword_ready")
	else:
		player.animation.play("fall")

func physics_update(_delta: float) -> void:
	if not Input.is_action_pressed("special_move"):
		if player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)
		return

	var move_dir = player.input.move_direction

	if Input.is_action_just_pressed("nav_up"):
		state_machine.change_state(state_machine.get_node("SwordUppercutState"))
		return

	if Input.is_action_just_pressed("nav_down"):
		if not player.is_on_floor():
			state_machine.change_state(state_machine.get_node("SwordDownslashState"))
			return

	if move_dir != 0 and move_dir == -player.facing_direction and move_dir != _ignore_dir:
		state_machine.change_state(state_machine.get_node("SwordSpinState"))
		return

	if move_dir != 0 and move_dir == player.facing_direction and move_dir != _ignore_dir:
		state_machine.change_state(state_machine.get_node("SwordDashState"))
		return

	_keep_stance()

func _keep_stance() -> void:
	if not player.is_on_floor():
		player.movement.stop()
		player.move_and_slide()
		return
	player.movement.stop()
	player.move_and_slide()
