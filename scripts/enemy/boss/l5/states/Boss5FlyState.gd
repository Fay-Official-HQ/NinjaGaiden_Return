extends BossState
class_name Boss5FlyState

## 当前正在飞往的目标点（世界坐标）
var _target: Vector2 = Vector2.INF
## 正弦波时间累积
var _sine_time: float = 0.0
## 关卡 FlyMark 节点下的所有飞行标记点
var _marks: Array[Marker2D] = []


func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("fly")
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0
	if _marks.is_empty():
		_load_marks()
	_pick_new_target()


func physics_update(delta: float) -> void:
	var data := boss.data as BossData_5
	if not data:
		return
	if _marks.is_empty():
		_load_marks()
	if _marks.is_empty() or _target == Vector2.INF:
		return

	var diff = _target - boss.global_position
	if diff.length() < data.reach_threshold:
		# 抵达目标点 → 请求 AI 决策下一步动作（当前为发射），否则继续随机选点飞
		var next_state: String = boss.ai_component.request_decision()
		if next_state != "BossFlyState":
			state_machine.change_state_by_name(next_state)
		else:
			_pick_new_target()
		return

	# 直线飞向目标 + 正弦波（垂直于飞行方向，与第二关 Boss 相同）
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * data.sine_frequency) * data.sine_amplitude * data.sine_frequency
	boss.global_position += (dir * data.fly_speed + perp * sine_vel) * delta

	# 始终面朝玩家方向
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)

	# 战斗区域约束：飞行不允许超出（左520/右1000/上0/下180，可在 BossData_5 调试）
	boss.global_position = _clamp_to_battle_area(boss.global_position, data)


## 收集当前关卡 FlyMark 节点下的所有 Marker2D 作为固定飞行点
func _load_marks() -> void:
	_marks.clear()
	var fly_mark = get_tree().current_scene.get_node_or_null("FlyMark") as Node2D
	if not fly_mark:
		return
	for child in fly_mark.get_children():
		if child is Marker2D:
			_marks.append(child)


## 随机选择一个飞行目标点（避免连续选中当前所在的点），并钳制在战斗区域内
func _pick_new_target() -> void:
	var data := boss.data as BossData_5
	if _marks.is_empty():
		return
	var last = _target
	var picked := false
	for i in 8:
		var mark = _marks[randi() % _marks.size()]
		if mark.global_position != last:
			_target = mark.global_position
			picked = true
			break
	# 循环 8 次都没选出不同点，退而求其次用第一个标记点
	if not picked:
		_target = _marks[0].global_position
	if data:
		_target = _clamp_to_battle_area(_target, data)


## 把坐标钳制到战斗区域矩形内（边界参数在 BossData_5，我需要调试）
func _clamp_to_battle_area(v: Vector2, data: BossData_5) -> Vector2:
	return Vector2(
		clampf(v.x, data.battle_area_left, data.battle_area_right),
		clampf(v.y, data.battle_area_top, data.battle_area_bottom)
	)
