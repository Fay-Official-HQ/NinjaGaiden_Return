extends Area2D
class_name FlyingNinja

## 飞天忍者：像抛石头一样减速上升 → 最高点(或下落途中)释放攻击 → 加速坠落

enum Phase { RISING, FALLING }

@export var data: FlyingNinjaData

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var _phase: int = Phase.RISING
var _is_dead: bool = false
var _velocity_y: float = 0.0
var _has_thrown: bool = false
var _fire_timer: float = 0.0


func _ready() -> void:
	_velocity_y = -data.rise_speed

	# 火焰忍者变红色
	if data.attack_type == FlyingNinjaData.AttackType.FIRE:
		anim.modulate = Color(1.0, 0.3, 0.3)

	AudioManager.play_sound(data.appear_sound)

	_face_initial_direction()
	anim.play("fly")

	hurtbox.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _phase:
		Phase.RISING:
			_update_rising(delta)
		Phase.FALLING:
			_update_falling(delta)


func _update_rising(delta: float) -> void:
	_velocity_y += data.rise_deceleration * delta
	global_position.y += _velocity_y * delta

	if _velocity_y >= 0.0:
		# 到达最高点
		global_position.y = round(global_position.y)
		_phase = Phase.FALLING
		_velocity_y = 0.0

		if data.attack_type == FlyingNinjaData.AttackType.DART:
			# 飞镖忍者：最高点立即释放
			_launch_projectile()
			_has_thrown = true
			anim.play("throw")
		else:
			# 火焰忍者：下落途中再释放，给玩家反应时间
			_fire_timer = data.fire_attack_delay


func _update_falling(delta: float) -> void:
	_velocity_y += data.rise_deceleration * delta * 1.5
	if _velocity_y > data.fall_speed:
		_velocity_y = data.fall_speed
	global_position.y += _velocity_y * delta

	# 火焰忍者：下落计时到 → 释放火焰
	if not _has_thrown and data.attack_type == FlyingNinjaData.AttackType.FIRE:
		_fire_timer -= delta
		if _fire_timer <= 0.0:
			_launch_projectile()
			_has_thrown = true
			anim.play("throw")


func _launch_projectile() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()

	match data.attack_type:
		FlyingNinjaData.AttackType.DART:
			AudioManager.play_sound(data.attack_sound_dart)
			_throw_dart(dir)
		FlyingNinjaData.AttackType.FIRE:
			AudioManager.play_sound(data.attack_sound_fire)
			_throw_fire(dir)


func _throw_dart(dir: Vector2) -> void:
	var dart_scene = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
	var dart = dart_scene.instantiate() as FlyingNinjaDart
	dart.initialize(dir, data.dart_speed)
	dart.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(dart)


func _throw_fire(dir: Vector2) -> void:
	var fire_scene = preload("res://scenes/enemy/l1/flying_ninja_fire.tscn")
	var fire = fire_scene.instantiate() as FlyingNinjaFire
	fire.initialize(dir, data.fire_speed)
	fire.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(fire)


func _face_initial_direction() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		anim.flip_h = player.global_position.x < global_position.x


# ==================== 受击 ====================

func _on_took_damage(_amount: int) -> void:
	if _is_dead:
		return
	_die()


func _die() -> void:
	_is_dead = true

	# 根据攻击类型选择死亡音效
	match data.attack_type:
		FlyingNinjaData.AttackType.DART:
			AudioManager.play_sound(data.death_sound_dart)
		FlyingNinjaData.AttackType.FIRE:
			AudioManager.play_sound(data.death_sound_fire)

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)

	set_process(false)

	anim.play(data.death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _on_screen_exited() -> void:
	if not _is_dead:
		queue_free()
