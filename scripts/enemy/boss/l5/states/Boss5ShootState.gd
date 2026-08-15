extends BossState
class_name Boss5ShootState

## 散射激光场景
const LASER_SCENE: PackedScene = preload("res://scenes/enemy/boss/l5/boss5_laser.tscn")

## 发射点节点路径（Mark 会跟随 Boss 面朝镜像，位置始终正确）
const MARKER_PATH: NodePath = ^"Mark/Marker2D1"

var _charge_time: float = 1.0
var _laser_count: int = 4
var _scatter_deg: float = 30.0
var _laser_speed: float = 300.0
var _flicker_min_alpha: float = 0.2
var _flicker_half_period: float = 0.125
var _laser_homing_turn_rate: float = 45.0
var _laser_homing_delay: float = 1.0
var _laser_hp: int = 1
var _laser_lifetime: float = 5.0
var _timer: float = 0.0
var _flicker_tween: Tween


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("shoot")
	# 面朝玩家蓄力
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)
	var data := boss.data as BossData_5
	if data:
		_charge_time = data.shoot_charge_time
		_laser_count = data.laser_count
		_scatter_deg = data.laser_scatter_deg
		_laser_speed = data.laser_speed
		_flicker_min_alpha = data.flicker_min_alpha
		_flicker_half_period = data.flicker_half_period
		_laser_homing_turn_rate = data.laser_homing_turn_rate
		_laser_homing_delay = data.laser_homing_delay
		_laser_hp = data.laser_hp
		_laser_lifetime = data.laser_lifetime
	_timer = 0.0
	# 蓄力期间显示能量动画并闪烁
	var energy := boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D
	if energy:
		energy.visible = true
		_start_flicker()


func update(delta: float) -> void:
	_timer += delta
	if _timer >= _charge_time:
		_fire_lasers()
		state_machine.change_state_by_name("BossFlyState")


func exit() -> void:
	# 发射后/退出时停止闪烁并隐藏能量动画
	_stop_flicker()


## 能量动画闪烁：alpha 在 0.2 ↔ 1.0 之间循环（蓄力期间持续显示）
func _start_flicker() -> void:
	var energy := boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D
	if not energy:
		return
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()
		_flicker_tween = null
	energy.modulate.a = 1.0
	energy.visible = true
	_flicker_tween = create_tween()
	_flicker_tween.tween_property(energy, "modulate:a", _flicker_min_alpha, _flicker_half_period)
	_flicker_tween.tween_property(energy, "modulate:a", 1.0, _flicker_half_period)
	_flicker_tween.set_loops()


func _stop_flicker() -> void:
	if _flicker_tween and _flicker_tween.is_valid():
		_flicker_tween.kill()
		_flicker_tween = null
	var energy := boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D
	if energy:
		energy.modulate.a = 1.0
		energy.visible = false


## 在发射点生成 4 个激光，朝玩家方向上下对称散射
func _fire_lasers() -> void:
	var marker := boss.get_node_or_null(MARKER_PATH) as Marker2D
	if not marker or not boss.player_ref:
		return
	AudioManager.play_sound(&"leidian")
	var base_dir: Vector2 = (boss.player_ref.global_position - marker.global_position).normalized()
	var scatter: float = deg_to_rad(_scatter_deg)
	for i in range(_laser_count):
		var t: float = -0.5
		if _laser_count > 1:
			t = lerpf(-0.5, 0.5, float(i) / float(_laser_count - 1))
		var dir: Vector2 = base_dir.rotated(t * scatter)
		var laser: boss5_laser = LASER_SCENE.instantiate()
		get_tree().current_scene.add_child(laser)
		laser.global_position = marker.global_position
		laser.initialize(dir, _laser_speed, _laser_homing_turn_rate, _laser_hp, _laser_homing_delay, _laser_lifetime)
