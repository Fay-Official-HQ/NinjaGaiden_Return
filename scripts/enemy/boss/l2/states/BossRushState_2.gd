extends BossState
class_name BossRushState_2

## 飞行阶段参数
const MOVE_SPEED: float = 120.0
const SINE_AMPLITUDE: float = 30.0
const SINE_FREQUENCY: float = 3.0
const REACH_THRESHOLD: float = 10.0
## 蓄力时间
const CHARGE_DURATION: float = 1.0
## 向左冲刺距离（与向右不同）
const DASH_DISTANCE_LEFT: float = 280.0
## 向右冲刺距离
const DASH_DISTANCE_RIGHT: float = 500.0
## 冲刺速度
const DASH_SPEED: float = 650.0

const POINT_NAMES: Array[String] = ["Point_L", "Point_R"]

var _offsets: Array[Vector2] = []
var _current_target_idx: int = 0
var _sine_time: float = 0.0

var _phase: int = 0  # 0=飞向目标, 1=蓄力, 2=冲刺
var _charge_timer: float = 0.0
var _dash_start_x: float = 0.0
var _dash_dir: float = 1.0


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0
	_phase = 0
	_charge_timer = 0.0

	if not _load_offsets():
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	boss.animated_sprite.play("fly")
	if boss.energy_animated:
		boss.energy_animated.visible = false
	if boss.fire_animated:
		boss.fire_animated.visible = false

	_current_target_idx = randi() % _offsets.size()


func physics_update(delta: float) -> void:
	if _offsets.is_empty() or not boss._camera_ref:
		return

	match _phase:
		0:
			_move_to_target(delta)
		1:
			_charge(delta)
		2:
			_dash(delta)


func _move_to_target(delta: float) -> void:
	if not boss.player_ref:
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]
	# Y轴跟踪玩家，X轴使用FirePath点偏移
	target.y = boss.player_ref.global_position.y

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		# 到达目标点 → 蓄力
		_phase = 1
		_charge_timer = CHARGE_DURATION
		boss.animated_sprite.play("charge")
		return

	# 正弦波飞行
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY

	boss.global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	# 面朝玩家
	var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(player_dir)


func _charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_execute_dash()
		return

	# 蓄力时身体变暗
	var t = 1.0 - _charge_timer / CHARGE_DURATION
	var dark = lerp(Color.WHITE, Color(0.3, 0.3, 0.3, 1.0), t)
	boss.animated_sprite.modulate = dark


func _execute_dash() -> void:
	_phase = 2
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.play("dash")
	AudioManager.play_sound(&"jianqianchong")
	_dash_dir = 1.0 if boss.player_ref and boss.player_ref.global_position.x > boss.global_position.x else -1.0
	_dash_start_x = boss.global_position.x
	boss.set_facing_direction(_dash_dir)


func _dash(_delta: float) -> void:
	var dash_distance = DASH_DISTANCE_RIGHT if _dash_dir > 0 else DASH_DISTANCE_LEFT
	var traveled = (boss.global_position.x - _dash_start_x) * _dash_dir
	if traveled >= dash_distance:
		boss.velocity.x = 0.0
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	boss.velocity.x = _dash_dir * DASH_SPEED


func exit() -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.modulate = Color.WHITE
	if boss.energy_animated:
		boss.energy_animated.visible = false
	if boss.fire_animated:
		boss.fire_animated.visible = false


func _load_offsets() -> bool:
	var fire_path = boss.get_node_or_null("FirePath") as Node2D
	if not fire_path:
		return false

	_offsets.clear()
	for point_name in POINT_NAMES:
		var marker = fire_path.get_node_or_null(point_name) as Marker2D
		if not marker:
			return false
		_offsets.append(marker.position)

	return _offsets.size() == POINT_NAMES.size()
