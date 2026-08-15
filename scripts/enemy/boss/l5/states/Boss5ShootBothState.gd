extends BossState
class_name Boss5ShootBothState

## 火凤凰投射物场景
const PHOENIX_SCENE: PackedScene = preload("res://scenes/enemy/boss/l5/fire_phoenix.tscn")

## 发射点节点路径（Mark 会跟随 Boss 面朝镜像，位置始终正确）
const MARKER_PATH: NodePath = ^"Mark/Marker2D1"

## 状态阶段：先垂直飞到玩家水平线，再蓄力发射
enum Phase { ALIGN, CHARGE }

var _phase: Phase = Phase.ALIGN
var _target_y: float = 0.0
var _align_speed: float = 150.0
var _align_tolerance: float = 5.0
var _min_align_y: float = 170.0
var _charge_time: float = 1.0
var _phoenix_speed: float = 300.0
var _phoenix_damage: int = 3
var _flicker_min_alpha: float = 0.2
var _flicker_half_period: float = 0.125
var _timer: float = 0.0
var _flicker_tween: Tween


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	var data := boss.data as BossData_5
	if data:
		_align_speed = data.phoenix_align_speed
		_align_tolerance = data.phoenix_align_tolerance
		_min_align_y = data.phoenix_min_align_y
		_charge_time = data.shoot_both_charge_time
		_phoenix_speed = data.phoenix_speed
		_phoenix_damage = data.phoenix_damage
		_flicker_min_alpha = data.flicker_min_alpha
		_flicker_half_period = data.flicker_half_period
	_phase = Phase.ALIGN
	_timer = 0.0
	# 面朝玩家，垂直飞向玩家的水平线（不高于最低高度限制）
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)
		_target_y = minf(boss.player_ref.global_position.y, _min_align_y)
	boss.animated_sprite.play("fly")


func update(delta: float) -> void:
	if _phase != Phase.CHARGE:
		return
	# 蓄力期间持续面朝玩家（玩家移动时也跟着转）
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)
	_timer += delta
	if _timer >= _charge_time:
		_fire_phoenix()
		state_machine.change_state_by_name("BossFlyState")


func physics_update(delta: float) -> void:
	if _phase != Phase.ALIGN:
		return
	# 从当前位置垂直移动到与玩家接近的水平线（偏离固定飞行路线）
	var diff = _target_y - boss.global_position.y
	if absf(diff) <= _align_tolerance:
		boss.global_position.y = _target_y
		_start_charge()
	else:
		boss.global_position.y += clampf(diff, -_align_speed * delta, _align_speed * delta)


func exit() -> void:
	# 发射后/退出时停止闪烁并隐藏能量动画
	_stop_flicker()


## 到达玩家水平线：切换双手发射动画并开始蓄力
func _start_charge() -> void:
	_phase = Phase.CHARGE
	_timer = 0.0
	boss.animated_sprite.play("shoot_both")
	var energy := boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D
	if energy:
		energy.visible = true
		_start_flicker()


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


## 朝玩家所在的左/右方向发射一个火凤凰（横向直线飞行，不可摧毁不可格挡）
func _fire_phoenix() -> void:
	var marker := boss.get_node_or_null(MARKER_PATH) as Marker2D
	if not marker or not boss.player_ref:
		return
	AudioManager.play_sound(&"jiguang")
	# 以 Boss 自身为基准判断玩家所在方向，确保永远朝玩家发射（不用发射点，
	# 因为 Marker2D1 随 Mark 镜像，玩家贴身时方向会取反）
	var dir: float = 1.0 if boss.player_ref.global_position.x >= boss.global_position.x else -1.0
	var phoenix: FirePhoenix = PHOENIX_SCENE.instantiate()
	get_tree().current_scene.add_child(phoenix)
	phoenix.global_position = marker.global_position
	# 伤害由数据驱动控制
	var hitbox = phoenix.get_node_or_null("EnemyHitBox")
	if hitbox and "damage" in hitbox:
		hitbox.damage = _phoenix_damage
	phoenix.initialize(dir, _phoenix_speed)
