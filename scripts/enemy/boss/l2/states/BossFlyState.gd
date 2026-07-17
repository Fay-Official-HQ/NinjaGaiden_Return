extends BossState
class_name BossFlyState

## 移动速度（像素/秒）
const MOVE_SPEED: float = 80.0
## 正弦波振幅（像素）
const SINE_AMPLITUDE: float = 30.0
## 正弦波频率（弧度/秒）
const SINE_FREQUENCY: float = 3.0
## 抵达目标判定距离（像素）
const REACH_THRESHOLD: float = 10.0

## 五个偏移点名称（在 BOSS 场景 FlyPath 下，相对于摄像机锚点的偏移）
const POINT_NAMES: Array[String] = ["Point_TL", "Point_TR", "Point_BR", "Point_BL", "Point_MD"]

## 5个偏移量（相对于画面中心的像素偏移）
var _offsets: Array[Vector2] = []
## 当前正在飞往的目标索引
var _current_target_idx: int = 0
## 记录本轮已访问过的点（四个全访问完算一轮完整巡逻）
var _visited_in_cycle: Array[bool] = []
## 正弦波时间累积
var _sine_time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("fly")
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0

	if not _load_offsets():
		return

	# 随机选一个起点
	_current_target_idx = randi() % _offsets.size()
	_visited_in_cycle = []
	_visited_in_cycle.resize(_offsets.size())


func update(_delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	if _offsets.is_empty() or not boss._camera_ref:
		return

	# 每帧重新计算目标世界坐标 = 摄像机当前视口中心 + 偏移量
	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		# 抵达目标点附近（不 snap，保持当前位置直接切下一个点）
		_visited_in_cycle[_current_target_idx] = true

		# 完成一轮完整巡逻（4个点全部访问过）→ 问 AI 下一步做什么
		if _visited_in_cycle.all(func(v): return v):
			var action = boss.ai_component.get_next_action()
			if action != "" and action != "BossFlyState":
				# AI 要求切换到新状态 → 走状态机切换
				state_machine.change_state_by_name(action)
			else:
				# AI 要求继续飞行（或还没决策）→ 直接在内部重置，不走状态机切换
				_visited_in_cycle = []
				_visited_in_cycle.resize(_offsets.size())
				_current_target_idx = randi() % _offsets.size()
				_sine_time = 0.0
				# 保持当前位置，直接飞向下一个随机点
				return
		else:
			# 继续访问未去过的点
			_current_target_idx = _pick_unvisited()
		return

	# 直线飞向目标 + 正弦波（垂直于飞行方向）
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	# 正弦波速度 = 振幅 × 频率 × cos(时间 × 频率)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY

	boss.global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	# 始终面朝玩家方向
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)


## 从未访问过的点中随机选一个
func _pick_unvisited() -> int:
	var unvisited: Array[int] = []
	for i in _offsets.size():
		if not _visited_in_cycle[i]:
			unvisited.append(i)
	if unvisited.is_empty():
		return randi() % _offsets.size()
	return unvisited[randi() % unvisited.size()]


## 从 BOSS 场景的 FlyPath 节点读取5个 Marker2D 的偏移量
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
