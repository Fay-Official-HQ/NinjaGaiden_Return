# res://scripts/enemy/boss/l3/states/Boss3FlightToTopState.gd
## 飞行到顶部标记点，到达后悬浮秒，然后自动进入下劈攻击
extends Boss3State
class_name Boss3FlightToTopState

var _target_pos: Vector2
var _start_pos: Vector2
var _flight_progress: float = -1.0
var _flight_duration: float = 0.0

## 到达目标后的悬浮计时（秒）
var _hover_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("fall_imbalance")
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true
	_hover_timer = 0.0

	var boss_marker = get_tree().current_scene.get_node_or_null("BossMarker2D")
	if not boss_marker or boss_marker.get_child_count() == 0:
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3SwordDownslashState")
		return

	# 收集三个顶部标记点
	var markers: Array[Marker2D] = []
	for marker_name in ["Marker2DTop", "Marker2DTop2", "Marker2DTop3"]:
		var marker = boss_marker.get_node_or_null(marker_name) as Marker2D
		if marker:
			markers.append(marker)

	if markers.is_empty():
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3SwordDownslashState")
		return

	# 选择离玩家最近的顶部标记点（按 X 轴距离）
	var player = boss.player_ref
	var closest: Marker2D = markers[0]
	var min_dist = INF
	for m in markers:
		var d = abs(m.global_position.x - player.global_position.x)
		if d < min_dist:
			min_dist = d
			closest = m
	_target_pos = closest.global_position

	boss.set_facing_direction(1.0 if _target_pos.x > boss.global_position.x else -1.0)

	_start_pos = boss.global_position
	var dist = _start_pos.distance_to(_target_pos)
	_flight_duration = dist / boss.data.flight_to_top_speed
	_flight_progress = 0.0

func update(delta: float) -> void:
	if _flight_progress < 0.0 and _hover_timer <= 0.0:
		return

	# ── 阶段 1：飞行 ──
	if _flight_progress >= 0.0:
		_flight_progress += delta
		var t = clampf(_flight_progress / _flight_duration, 0.0, 1.0)

		boss.global_position = _start_pos.lerp(_target_pos, t)
		boss.velocity = Vector2(1, 0)

		if t >= 1.0:
			# 到达目标 → 进入悬浮阶段
			_flight_progress = -1.0
			boss.global_position = _target_pos
			boss.velocity = Vector2.ZERO
			_hover_timer = boss.data.flight_hover_duration
		return

	# ── 阶段 2：悬浮（时长由 data.flight_hover_duration 控制） ──
	if _hover_timer > 0.0:
		_hover_timer -= delta
		boss.velocity = Vector2.ZERO
		if _hover_timer <= 0.0:
			_on_hover_end()

func _on_hover_end() -> void:
	_hover_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = false
	state_machine.change_state_by_name("Boss3SwordDownslashState")

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	super()
	_flight_progress = -1.0
	_hover_timer = 0.0
	boss.ignore_gravity = false
