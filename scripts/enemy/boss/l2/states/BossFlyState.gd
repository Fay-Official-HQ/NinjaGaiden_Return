extends BossState
class_name BossFlyState

## 移动速度（像素/秒）
const MOVE_SPEED: float = 120.0
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
## 正弦波时间累积
var _sine_time: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("fly")
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0

	# 隐藏 EnergyAnimated
	if boss.energy_animated:
		boss.energy_animated.visible = false

	if not _load_offsets():
		return

	# 随机选一个点作为本次飞行目标
	_current_target_idx = randi() % _offsets.size()


func physics_update(delta: float) -> void:
	if _offsets.is_empty() or not boss._camera_ref:
		return

	# 每帧重新计算目标世界坐标 = 摄像机当前视口中心 + 偏移量
	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		# 抵达目标点 → 按顺序切换下一状态
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	# 直线飞向目标 + 正弦波（垂直于飞行方向）
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY

	boss.global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	# 始终面朝玩家方向
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)


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
