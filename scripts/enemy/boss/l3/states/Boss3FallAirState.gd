# res://scripts/enemy/boss/l3/states/Boss3FallAirState.gd
## 空中失衡状态（直线飞行）：Boss 直线飞到 BossMarker2D 随机标记点，然后自由下落
extends Boss3State
class_name Boss3FallAirState

var _target_pos: Vector2
var _start_pos: Vector2
var _flight_progress: float = -1.0
var _flight_duration: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("fall_imbalance")
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true

	# 只飞 Marker2DRight2 或 Marker2DLeft2
	var boss_marker = get_tree().current_scene.get_node_or_null("BossMarker2D")
	if not boss_marker or boss_marker.get_child_count() == 0:
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3FallState")
		return

	var candidates: Array[Marker2D] = []
	for marker_name in ["Marker2DRight2", "Marker2DLeft2"]:
		var marker = boss_marker.get_node_or_null(marker_name) as Marker2D
		if marker:
			candidates.append(marker)

	if candidates.is_empty():
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3FallState")
		return

	var chosen = candidates[randi() % candidates.size()]
	_target_pos = chosen.global_position

	if _target_pos.distance_squared_to(boss.global_position) < 100.0:
		var retry = candidates[randi() % candidates.size()]
		_target_pos = retry.global_position

	# 面向目标方向
	boss.set_facing_direction(1.0 if _target_pos.x > boss.global_position.x else -1.0)

	# 初始化直线飞行参数（不用 Tween，在 update 手动设置位置）
	_start_pos = boss.global_position
	var dist = _start_pos.distance_to(_target_pos)
	_flight_duration = dist / boss.data.fall_air_fly_speed
	_flight_progress = 0.0

func update(delta: float) -> void:
	if _flight_progress < 0.0:
		return

	_flight_progress += delta
	var t = clampf(_flight_progress / _flight_duration, 0.0, 1.0)

	# 直线插值到目标点（无视地形）
	boss.global_position = _start_pos.lerp(_target_pos, t)

	# 设非零 velocity 防止 boss_3.gd:abs(velocity.x) < 1.0 锁定 x
	boss.velocity = Vector2(1, 0)

	if t >= 1.0:
		_on_flight_end()

func _on_flight_end() -> void:
	_flight_progress = -1.0
	boss.global_position = _target_pos
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = false
	state_machine.change_state_by_name("Boss3FallState")

func physics_update(_delta: float) -> void:
	# 飞行期间位置已由 update 控制，physics 不做任何处理
	pass

func exit() -> void:
	super()
	_flight_progress = -1.0
	boss.ignore_gravity = false
