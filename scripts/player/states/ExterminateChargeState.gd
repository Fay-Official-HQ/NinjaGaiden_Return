extends State
class_name ExterminateChargeState

const MAX_CHARGE_TIME = 3.0
const MAX_ENERGY = 6
const ENERGY_INTERVAL = 0.5

var _charge_timer: float = 0.0
var _energy_level: int = 0
var _energy_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	AudioManager.play_sound(&"renshuhuoqiu")
	_charge_timer = 0.0
	_energy_level = 0
	_energy_timer = 0.0

func update(delta: float) -> void:
	_charge_timer = min(_charge_timer + delta, MAX_CHARGE_TIME)
	_energy_timer += delta
	if _energy_timer >= ENERGY_INTERVAL and _energy_level < MAX_ENERGY:
		_energy_level += 1
		_energy_timer -= ENERGY_INTERVAL

	var redness = _charge_timer / MAX_CHARGE_TIME
	player.animated_sprite.modulate = Color(1.0, 1.0 - redness * 0.8, 1.0 - redness * 0.8)

func physics_update(_delta: float) -> void:
	if Input.is_action_just_released("attack"):
		state_machine.change_state(
			state_machine.get_node("ExterminateReleaseState"),
			{"energy": _energy_level}
		)
		return

	# 跳跃
	if player.input.consume_jump():
		_exit_charge()
		state_machine.change_state(player.jump_state)
		return

	# 下蹲
	if Input.is_action_pressed("nav_down"):
		_exit_charge()
		state_machine.change_state(state_machine.get_node("CrouchState"))
		return

	# 剑术备战
	if Input.is_action_pressed("special_move"):
		_exit_charge()
		state_machine.change_state(state_machine.get_node("SwordReadyState"))
		return

	# 踩空坠落
	if not player.is_on_floor():
		_exit_charge()
		state_machine.change_state(player.fall_state, {"imbalance": true})
		return

	# 水平移动
	var move_dir = player.input.move_direction
	if move_dir != 0:
		player.set_facing_direction(move_dir)
		player.movement.move(move_dir)
	else:
		player.movement.stop()

	player.move_and_slide()

func exit() -> void:
	player.animated_sprite.modulate = Color.WHITE

func _exit_charge() -> void:
	player.animated_sprite.modulate = Color.WHITE
