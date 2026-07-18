extends BossState
class_name BossSpineState

## 飞行阶段参数
const MOVE_SPEED: float = 120.0
const SINE_AMPLITUDE: float = 30.0
const SINE_FREQUENCY: float = 3.0
const REACH_THRESHOLD: float = 10.0
## 逐渐消失/出现时间
const FADE_DURATION: float = 0.5
## 尖刺蓄力时间
const SPINE_CHARGE_DURATION: float = 1.0
## 投射物速度
const SPINE_SPEED: float = 600.0
## 每侧发射数量
const SPINE_COUNT_PER_SIDE: int = 4
## 散射角度范围（度）
const SPREAD_ANGLE_DEG: float = 45.0

const POINT_NAMES: Array[String] = ["Point_L", "Point_M", "Point_R"]
const MD_POINT_NAME: String = "Point_MD"

var _offsets: Array[Vector2] = []
var _current_target_idx: int = 0
var _sine_time: float = 0.0

var _phase: int = 0  # 0=飞行, 1=消失, 2=出现, 3=蓄力, 4=发射
var _fade_timer: float = 0.0
var _charge_timer: float = 0.0
var _md_offset: Vector2 = Vector2.ZERO

var _spine_scene: PackedScene = preload("res://scenes/enemy/boss/l2/boss_‌spine.tscn")


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_sine_time = 0.0
	_phase = 0
	_fade_timer = 0.0
	_charge_timer = 0.0

	if not _load_offsets():
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	if boss.energy_animated:
		boss.energy_animated.visible = false
	if boss.fire_animated:
		boss.fire_animated.visible = false

	boss.animated_sprite.play("fly")
	_current_target_idx = randi() % _offsets.size()


func physics_update(delta: float) -> void:
	if _offsets.is_empty() or not boss._camera_ref:
		return

	match _phase:
		0:
			_move_to_target(delta)
		1:
			_fade_out(delta)
		2:
			_fade_in(delta)
		3:
			_charge(delta)
		4:
			_fire_spines()


func _move_to_target(delta: float) -> void:
	if not boss.player_ref:
		state_machine.change_state_by_name(boss.ai_component.request_decision())
		return

	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		# 到达目标点 → 开始消失
		_phase = 1
		_fade_timer = FADE_DURATION
		boss.animated_sprite.play("charge")
		boss.hurt_box.set_deferred("monitoring", false)
		return

	# 正弦波飞行
	_sine_time += delta
	var dir = diff / diff.length()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY

	boss.global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(player_dir)


func _fade_out(delta: float) -> void:
	_fade_timer -= delta
	var alpha = clampf(_fade_timer / FADE_DURATION, 0.0, 1.0)
	boss.modulate.a = alpha

	if _fade_timer <= 0.0:
		boss.modulate.a = 0.0
		# 移动到 Point_MD 位置
		var center = boss._camera_ref.get_screen_center_position()
		boss.global_position = center + _md_offset
		# 进入出现阶段
		_phase = 2
		_fade_timer = FADE_DURATION
		boss.animated_sprite.play("bisha")


func _fade_in(delta: float) -> void:
	_fade_timer -= delta
	var alpha = 1.0 - clampf(_fade_timer / FADE_DURATION, 0.0, 1.0)
	boss.modulate.a = alpha

	if _fade_timer <= 0.0:
		boss.modulate.a = 1.0
		# 进入蓄力阶段，恢复可受伤
		boss.hurt_box.set_deferred("monitoring", true)
		_phase = 3
		_charge_timer = SPINE_CHARGE_DURATION
		boss.animated_sprite.play("spine")


func _charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_phase = 4
		return

	var t = 1.0 - _charge_timer / SPINE_CHARGE_DURATION
	var dark = lerp(Color.WHITE, Color(0.3, 0.3, 0.3, 1.0), t)
	boss.animated_sprite.modulate = dark


func _fire_spines() -> void:
	boss.animated_sprite.modulate = Color.WHITE

	# 左右各发射 SPINE_COUNT_PER_SIDE 枚
	var half_span = deg_to_rad(SPREAD_ANGLE_DEG * 0.5)

	for i in range(SPINE_COUNT_PER_SIDE):
		var angle = -half_span + half_span * 2.0 / (SPINE_COUNT_PER_SIDE - 1) * i if SPINE_COUNT_PER_SIDE > 1 else 0.0
		_spawn_spine(Vector2(cos(angle), sin(angle)).normalized())      # 右
		_spawn_spine(Vector2(-cos(angle), sin(angle)).normalized())     # 左

	AudioManager.play_sound(&"jianci")

	state_machine.change_state_by_name(boss.ai_component.request_decision())


func _spawn_spine(dir: Vector2) -> void:
	var spine = _spine_scene.instantiate()
	spine.global_position = boss.global_position
	spine.initialize(dir, SPINE_SPEED)
	get_tree().current_scene.add_child(spine)


func exit() -> void:
	boss.velocity = Vector2.ZERO
	boss.modulate.a = 1.0
	boss.animated_sprite.modulate = Color.WHITE
	boss.hurt_box.set_deferred("monitoring", true)
	if boss.energy_animated:
		boss.energy_animated.visible = false
	if boss.fire_animated:
		boss.fire_animated.visible = false


func _load_offsets() -> bool:
	var spine_path = boss.get_node_or_null("SpinePath") as Node2D
	if not spine_path:
		return false

	_offsets.clear()
	for point_name in POINT_NAMES:
		var marker = spine_path.get_node_or_null(point_name) as Marker2D
		if not marker:
			return false
		_offsets.append(marker.position)

	if _offsets.size() != POINT_NAMES.size():
		return false

	# 同时加载 Point_MD 偏移
	var fly_path = boss.get_node_or_null("FlyPath") as Node2D
	if not fly_path:
		return false
	var md_marker = fly_path.get_node_or_null(MD_POINT_NAME) as Marker2D
	if not md_marker:
		return false
	_md_offset = md_marker.position

	return true
