extends Area2D
class_name FlyingNinja

## 飞天忍者：像抛石头一样减速上升 → 最高点扔镖 → 加速坠落

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


func _ready() -> void:
	_velocity_y = -data.rise_speed

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
	# 减速上升（向上为负）
	_velocity_y += data.rise_deceleration * delta
	global_position.y += _velocity_y * delta

	# 速度 >= 0 说明到达最高点
	if _velocity_y >= 0.0:
		# 最高点：同时扔镖、播 throw 动画、开始坠落
		_throw_dart()
		_has_thrown = true
		anim.play("throw")
		_phase = Phase.FALLING
		_velocity_y = 0.0


func _update_falling(delta: float) -> void:
	# 先加速到 fall_speed
	_velocity_y += data.rise_deceleration * delta * 1.5
	if _velocity_y > data.fall_speed:
		_velocity_y = data.fall_speed
	global_position.y += _velocity_y * delta


func _throw_dart() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dart_scene = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
	var dart = dart_scene.instantiate() as FlyingNinjaDart
	var dir = (player.global_position - global_position).normalized()
	dart.initialize(dir, data.dart_speed)
	dart.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(dart)


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

	AudioManager.play_sound(data.death_sound)

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
