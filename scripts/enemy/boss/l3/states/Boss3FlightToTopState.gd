# res://scripts/enemy/boss/l3/states/Boss3FlightToTopState.gd
## 飞行到顶部标记点，到达后自动进入下劈攻击
extends Boss3State
class_name Boss3FlightToTopState

var _target_pos: Vector2
var _start_pos: Vector2
var _flight_progress: float = -1.0
var _flight_duration: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("fall_imbalance")
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true

	var boss_marker = get_tree().current_scene.get_node_or_null("BossMarker2D")
	if not boss_marker or boss_marker.get_child_count() == 0:
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3SwordDownslashState")
		return

	var candidates: Array[Marker2D] = []
	for marker_name in ["Marker2DTop", "Marker2DTop2", "Marker2DTop3"]:
		var marker = boss_marker.get_node_or_null(marker_name) as Marker2D
		if marker:
			candidates.append(marker)

	if candidates.is_empty():
		boss.ignore_gravity = false
		state_machine.change_state_by_name("Boss3SwordDownslashState")
		return

	var chosen = candidates[randi() % candidates.size()]
	_target_pos = chosen.global_position

	boss.set_facing_direction(1.0 if _target_pos.x > boss.global_position.x else -1.0)

	_start_pos = boss.global_position
	var dist = _start_pos.distance_to(_target_pos)
	_flight_duration = dist / boss.data.flight_to_top_speed
	_flight_progress = 0.0

func update(delta: float) -> void:
	if _flight_progress < 0.0:
		return

	_flight_progress += delta
	var t = clampf(_flight_progress / _flight_duration, 0.0, 1.0)

	boss.global_position = _start_pos.lerp(_target_pos, t)

	# 设非零 velocity 防止 boss_3.gd 锁定 x
	boss.velocity = Vector2(1, 0)

	if t >= 1.0:
		_on_flight_end()

func _on_flight_end() -> void:
	_flight_progress = -1.0
	boss.global_position = _target_pos
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = false
	state_machine.change_state_by_name("Boss3SwordDownslashState")

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	super()
	_flight_progress = -1.0
	boss.ignore_gravity = false
