extends CharacterBody2D
class_name StoneProjectile

## 重力加速度（像素/秒²）
const GRAVITY: float = 980.0
## 落地弹跳保留速度比例（0.6=保留60%速度）
const BOUNCE_DAMP: float = 0.6
## 撞墙反弹保留速度比例
const WALL_BOUNCE_DAMP: float = 0.5
## 地面滚动摩擦力（每帧乘0.85=逐渐减速）
const FLOOR_FRICTION: float = 0.85
## 低于此弹跳速度（像素/秒）→转为滚动
const MIN_BOUNCE_SPEED: float = 30.0
## 低于此滚动速度→停止
const MIN_ROLL_SPEED: float = 5.0
## 静止后等待删除的时间（秒）
const IDLE_DELETE_DELAY: float = 0.5
## 最大生命值
const MAX_HP: int = 1

## 低于此速度不播放撞击音效（避免静止时的噪音）
const MIN_HIT_SOUND_SPEED: float = 50.0

var _velocity: Vector2 = Vector2.ZERO
var _hp: int
var _is_dead: bool = false
var _idle_timer: float = 0.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var hurtbox: Area2D = $HurtBox
@onready var enemy_hitbox: Area2D = $EnemyHitBox


func _ready() -> void:
	_hp = MAX_HP
	screen_notifier.screen_exited.connect(_on_screen_exited)
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)


func initialize(x_velocity: float, y_velocity: float) -> void:
	_velocity = Vector2(x_velocity, y_velocity)
	anim.flip_h = x_velocity < 0
	anim.play("fly")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_velocity.y += GRAVITY * delta

	velocity = _velocity
	move_and_slide()

	if is_on_floor():
		if _velocity.y > MIN_BOUNCE_SPEED:
			_velocity.y = -_velocity.y * BOUNCE_DAMP
			_velocity.x *= BOUNCE_DAMP
			if abs(_velocity.y) > MIN_HIT_SOUND_SPEED:
				AudioManager.play_sound(&"shitou")
		else:
			_velocity.y = 0.0
			_velocity.x *= FLOOR_FRICTION
			if abs(_velocity.x) < MIN_ROLL_SPEED:
				_velocity.x = 0.0
				anim.play("fly")
			else:
				anim.play("roll")
	elif is_on_ceiling():
		_velocity.y = abs(_velocity.y) * BOUNCE_DAMP

	if is_on_wall():
		_velocity.x = -_velocity.x * WALL_BOUNCE_DAMP
		if abs(_velocity.x) > MIN_HIT_SOUND_SPEED:
			AudioManager.play_sound(&"shitou")

	if abs(_velocity.x) > MIN_ROLL_SPEED:
		anim.flip_h = _velocity.x < 0

	_check_idle(delta)


## 静止计时：速度接近0时开始倒计时，0.5秒后消失
func _check_idle(delta: float) -> void:
	if abs(_velocity.x) < MIN_ROLL_SPEED and abs(_velocity.y) < 1.0:
		_idle_timer += delta
		if _idle_timer >= IDLE_DELETE_DELAY:
			queue_free()
	else:
		_idle_timer = 0.0


func _on_took_damage(_amount: int, _is_heavy: bool) -> void:
	if _is_dead:
		return
	_hp -= 1
	if _hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(&"disiwang")
	set_physics_process(false)
	if enemy_hitbox:
		enemy_hitbox.set_deferred("monitoring", false)
		enemy_hitbox.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()


func _on_screen_exited() -> void:
	if not _is_dead:
		queue_free()
