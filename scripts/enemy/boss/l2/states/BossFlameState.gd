extends BossState
class_name BossFlameState

## 飞行阶段参数
const MOVE_SPEED: float = 120.0
const SINE_AMPLITUDE: float = 30.0
const SINE_FREQUENCY: float = 3.0
const REACH_THRESHOLD: float = 10.0
## 蓄力时间
const CHARGE_DURATION: float = 0.7
## 火焰弹速度
const FLAME_SPEED: float = 700.0

const POINT_NAMES: Array[String] = ["Point_L", "Point_R"]

var _offsets: Array[Vector2] = []
var _current_target_idx: int = 0
var _sine_time: float = 0.0

var _phase: int = 0  # 0=飞向目标, 1=蓄力, 2=发射
var _charge_timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0
	_phase = 0

	if not _load_offsets():
		state_machine.change_state_by_name("BossFlyState")
		return

	boss.animated_sprite.play("fly")
	if boss.fire_animated:
		boss.fire_animated.visible = false

	_current_target_idx = randi() % _offsets.size()


func physics_update(delta: float) -> void:
	if _offsets.is_empty() or not boss._camera_ref:
		return

	if _phase == 0:
		_move_to_target(delta)
	elif _phase == 1:
		_charge(delta)
	elif _phase == 2:
		_fire_flame()


func _move_to_target(delta: float) -> void:
	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]
	# Y轴使用玩家坐标，X轴使用点的偏移
	if boss.player_ref:
		target.y = boss.player_ref.global_position.y

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		# 到达目标点 → 蓄力准备发射
		boss.animated_sprite.play("fire")
		if boss.fire_animated:
			boss.fire_animated.visible = true
			boss.fire_animated.play("default")
		_phase = 1
		_charge_timer = CHARGE_DURATION
		return

	# 正弦波飞行（与 FlyState 一致）
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY

	boss.global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)


func _charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_phase = 2
		return

	# 闪烁效果
	if boss.fire_animated:
		boss.fire_animated.visible = int(_charge_timer * 10) % 2 == 0
	if boss.energy_animated:
		boss.energy_animated.visible = false


func _fire_flame() -> void:
	# 水平发射火焰弹（朝向玩家方向）
	var dir = Vector2.LEFT if boss.animated_sprite.flip_h else Vector2.RIGHT

	var flame_scene = preload("res://scenes/enemy/boss/l2/boss_fire.tscn")
	var flame = flame_scene.instantiate()
	# 从 FireAnimated 手部位置发射
	if boss.fire_animated:
		flame.global_position = boss.fire_animated.global_position
	else:
		flame.global_position = boss.global_position + Vector2(0, -10)
	flame.initialize(dir, FLAME_SPEED)
	get_tree().current_scene.add_child(flame)

	AudioManager.play_sound(&"shibingfashe")

	# 隐藏火焰动画
	if boss.fire_animated:
		boss.fire_animated.visible = false

	# 按顺序决策下一步
	state_machine.change_state_by_name(boss.ai_component.request_decision())


func exit() -> void:
	if boss.fire_animated:
		boss.fire_animated.visible = false
	if boss.energy_animated:
		boss.energy_animated.visible = false


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
