extends BossState
class_name BossUpRushState

## 飞行阶段参数
const MOVE_SPEED: float = 120.0
const SINE_AMPLITUDE: float = 30.0
const SINE_FREQUENCY: float = 3.0
const REACH_THRESHOLD: float = 10.0
## 蓄力时间
const CHARGE_DURATION: float = 1.0
## 从 Point_BR 出发的冲刺距离
const DASH_DISTANCE_BR: float = 250.0
## 从 Point_BL 出发的冲刺距离
const DASH_DISTANCE_BL: float = 400.0
## 冲刺速度
const DASH_SPEED: float = 650.0

const POINT_NAMES: Array[String] = ["Point_BR", "Point_BL"]

var _offsets: Array[Vector2] = []
var _current_target_idx: int = 0
var _sine_time: float = 0.0

var _phase: int = 0  # 0=飞向目标, 1=蓄力, 2=冲刺
var _charge_timer: float = 0.0
var _dash_start_pos: Vector2 = Vector2.ZERO
var _dash_dir: Vector2 = Vector2.ZERO
var _dash_distance: float = 0.0


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
	boss.animated_sprite.play("up")
	AudioManager.play_sound(&"jianqianchong")

	# 计算朝向玩家的方向向量（斜向冲刺）
	if boss.player_ref:
		_dash_dir = (boss.player_ref.global_position - boss.global_position).normalized()
	else:
		_dash_dir = Vector2.DOWN

	# 根据出发点设置不同的冲刺距离
	var point_name = POINT_NAMES[_current_target_idx]
	_dash_distance = DASH_DISTANCE_BR if point_name == "Point_BR" else DASH_DISTANCE_BL

	_dash_start_pos = boss.global_position
	boss.set_facing_direction(sign(_dash_dir.x))


func _dash(_delta: float) -> void:
	var traveled = (boss.global_position - _dash_start_pos).length()
	if traveled >= _dash_distance:
		boss.velocity = Vector2.ZERO
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	boss.velocity = _dash_dir * DASH_SPEED


func exit() -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.modulate = Color.WHITE
	if boss.energy_animated:
		boss.energy_animated.visible = false
	if boss.fire_animated:
		boss.fire_animated.visible = false


func _load_offsets() -> bool:
	var fly_path = boss.get_node_or_null("FlyPath") as Node2D
	if not fly_path:
		return false

	_offsets.clear()
	for point_name in POINT_NAMES:
		var marker = fly_path.get_node_or_null(point_name) as Marker2D
		if not marker:
			return false
		_offsets.append(marker.position)

	return _offsets.size() == POINT_NAMES.size()
