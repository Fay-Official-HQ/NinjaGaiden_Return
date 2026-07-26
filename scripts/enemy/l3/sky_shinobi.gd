extends Area2D
class_name SkyShinobi

## SkyShinobi —— 飞天忍者（双形态）
## ============================================================
##  功能和 FlyingNinja 一致：减速上升 → 最高点释放攻击 → 加速坠落
##  区别：有女人（飞镖）/ 男人（火球）两种模式
##  女人：fly1/throw1 + 3 枚散射忍镖
##  男人：fly2/throw2 + 3 枚散射火球
## ============================================================

enum Gender { FEMALE, MALE }
enum Phase { RISING, FALLING }

# ==================== 导出参数（Inspector 调试） ====================

@export var gender: int = Gender.FEMALE       # 0=女人（飞镖），1=男人（火球）

## 初始向上爆发速度（像素/秒）
@export var rise_speed: float = 500.0
## 上升减速度（像素/秒²）
@export var rise_deceleration: float = 550.0
## 下坠最大速度（像素/秒）
@export var fall_speed: float = 500.0

## 投掷物飞行速度（像素/秒）
@export var projectile_speed: float = 450.0
## 散射角度（度），中心一发 + 两侧各偏转此角度
@export var scatter_angle: float = 20.0

## 身体接触伤害
@export var contact_damage: int = 1

## 出现音效
@export var appear_sound: StringName = &"jianxuanzhuan"
## 攻击音效
@export var attack_sound: StringName = &"rengbiao"
## 死亡音效
@export var death_sound: StringName = &"disiwang"


# ==================== 节点引用 ====================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


# ==================== 运行时状态 ====================

var _phase: int = Phase.RISING
var _is_dead: bool = false
var _current_hp: int = 1
var _velocity_y: float = 0.0
var _has_thrown: bool = false


func _ready() -> void:
	_current_hp = 1    # 默认 1 刀死，可在 Inspector 改 max_hp 但不想加更多参数
	_velocity_y = -rise_speed

	AudioManager.play_sound(appear_sound)
	_face_player()
	anim.play("fly1" if gender == Gender.FEMALE else "fly2")

	hurtbox.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)

	# 设置 HitBox 接触伤害
	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _phase:
		Phase.RISING:
			_update_rising(delta)
		Phase.FALLING:
			_update_falling(delta)


func _update_rising(delta: float) -> void:
	_velocity_y += rise_deceleration * delta
	global_position.y += _velocity_y * delta

	if _velocity_y >= 0.0:
		# 到达最高点 → 释放攻击
		global_position.y = round(global_position.y)
		_phase = Phase.FALLING
		_velocity_y = 0.0

		_launch_projectile()
		_has_thrown = true
		anim.play("throw1" if gender == Gender.FEMALE else "throw2")


func _update_falling(delta: float) -> void:
	_velocity_y += rise_deceleration * delta * 1.5
	if _velocity_y > fall_speed:
		_velocity_y = fall_speed
	global_position.y += _velocity_y * delta


# ==================== 攻击 ====================

func _launch_projectile() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()
	var angle_rad = deg_to_rad(scatter_angle)

	# 3 枚散射：左 / 中 / 右
	var directions = [
		dir.rotated(-angle_rad),
		dir,
		dir.rotated(angle_rad),
	]

	if gender == Gender.MALE:
		AudioManager.play_sound(&"shibingfashe")
	else:
		AudioManager.play_sound(attack_sound)

	for d in directions:
		match gender:
			Gender.FEMALE:
				_throw_dart(d)
			Gender.MALE:
				_throw_fire(d)


func _throw_dart(dir: Vector2) -> void:
	var dart_scene = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
	var dart = dart_scene.instantiate() as FlyingNinjaDart
	dart.initialize(dir, projectile_speed)
	dart.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(dart)


func _throw_fire(dir: Vector2) -> void:
	var fire_scene = preload("res://scenes/enemy/boss/l2/boss_fireball.tscn")
	var fire = fire_scene.instantiate() as BossFireball
	fire.initialize(dir, projectile_speed)
	fire.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(fire)


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		anim.flip_h = player.global_position.x < global_position.x


# ==================== 受伤/死亡 ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_current_hp -= amount
	if _current_hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true

	AudioManager.play_sound(death_sound)

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)

	set_process(false)

	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _on_screen_exited() -> void:
	if not _is_dead:
		queue_free()
