extends Area2D
class_name EagleEnemy


## ============================================================
##  EagleEnemy —— 老鹰敌人
## ============================================================
##
##  行为：DIVING → TURNING → DIVING 两态无限循环
##
##  DIVING  曲线加速向玩家俯冲，时刻面向玩家。
##          加速到最大速度后锁定直线方向，飞过玩家一段距离后切 TURNING。
##  TURNING 平滑减速到0（无论屏幕内外），自动转身进入下一轮 DIVING。
##          全程无急停，速度连续变化。
##
##  场景结构（与蝙蝠相同）：
##    EagleEnemy (Area2D)
##    ├─ AnimatedSprite2D           ← fly(循环) / death(单次)
##    ├─ CollisionShape2D           ← 身体碰撞
##    ├─ HurtBox (Area2D)           ← 受击框，挂 HurtBox.gd
##    │   └─ CollisionShape2D
##    └─ HitBox (Area2D)            ← 伤害框，挂 EnemyHitBox.gd
##        └─ CollisionShape2D
##
##  数据在 EagleData.tres 中配置，无需硬编码
## ============================================================


enum Phase { DIVING, TURNING }

@export var data: EagleData

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox

var _phase: int = Phase.DIVING
var _is_dead: bool = false
var _curve_velocity: Vector2 = Vector2.ZERO
var _dive_locked: bool = false
var _locked_direction: Vector2
var _dive_start_position: Vector2       # 锁定方向时的位置，用于判断飞行距离


func _ready() -> void:
	anim.play("fly")
	hurtbox.took_damage.connect(_on_took_damage)


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _phase:
		Phase.DIVING:
			_update_dive(delta)
		Phase.TURNING:
			_update_turn(delta)


func _update_dive(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	if not _dive_locked:
		# 阶段1：曲线加速，追踪玩家方向
		var to_player = (player.global_position - global_position).normalized()
		_curve_velocity = _curve_velocity.lerp(
			to_player * data.move_speed,
			delta * data.dive_curve_strength * 0.01
		)
		_face_player()

		# 加速到接近最大速度时 → 锁定直线方向，不再追踪玩家
		if _curve_velocity.length() >= data.move_speed * 0.95:
			_dive_locked = true
			_locked_direction = _curve_velocity.normalized()
			_dive_start_position = global_position
	else:
		# 阶段2：锁定方向，直线高速俯冲（此时轨迹固定，可被跳跃躲避）
		_curve_velocity = _locked_direction * data.move_speed

	global_position += _curve_velocity * delta

	# 锁定后飞够一定距离 → 切 TURNING 开始减速掉头
	if _dive_locked:
		var fly_distance = global_position.distance_squared_to(_dive_start_position)
		if fly_distance > 40000:
			_phase = Phase.TURNING
			_dive_locked = false


func _update_turn(delta: float) -> void:
	# 平滑减速，不论在屏幕内还是屏幕外
	var speed = _curve_velocity.length()
	speed -= data.turn_deceleration * delta
	if speed <= 0.0:
		speed = 0.0
		# 速度减到0 → 自动转身进入下一轮俯冲
		_phase = Phase.DIVING

	if speed > 0.0:
		_curve_velocity = _curve_velocity.normalized() * speed
		global_position += _curve_velocity * delta


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	anim.flip_h = player.global_position.x < global_position.x


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
