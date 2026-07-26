extends CharacterBody2D
class_name WhiteNinja

## WhiteNinja —— 空降忍者
## ============================================================
##  1. 生成 → 抛物线下坠到玩家前方/后方目标位置（fly 动画）
##  2. 落地 → idle 0.5s
##  3. 播放 throw 动画 → 掷出一枚忍镖
##  4. 斜上方 45° 远离玩家飞走
## ============================================================

# ==================== 导出参数（Inspector 调试） ====================

## 下坠初始上升速度（像素/秒，负值向上），形成抛物线弧
@export var ascend_v_speed: float = -350.0
## 下坠水平移动速度（像素/秒）
@export var descend_h_speed: float = 150.0
## 下坠重力加速度（像素/秒²）
@export var descend_gravity: float = 980.0
## 落地后待机时间（秒）
@export var idle_duration: float = 0.3
## 投掷物飞行速度（像素/秒）
@export var dart_speed: float = 400.0
## 逃离水平速度（像素/秒）
@export var flee_h_speed: float = 150.0
## 逃离垂直速度（像素/秒，负值向上）
@export var flee_v_speed: float = -300.0
## 身体接触伤害
@export var contact_damage: int = 1
## 最大血量
@export var max_hp: int = 1

## 出现音效
@export var appear_sound: StringName = &"jianxuanzhuan"
## 投掷音效
@export var throw_sound: StringName = &"rengbiao"
## 死亡音效
@export var death_sound: StringName = &"disiwang"


# ==================== 节点引用 ====================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


# ==================== 状态枚举 ====================

enum State { DESCENDING, IDLE, THROW, HOLD, FLEEING }


# ==================== 运行时状态 ====================

## 由 Spawner 设置：目标落点 X 坐标（世界坐标）
var target_landing_x: float = 0.0

var _state: int = State.DESCENDING
var _is_dead: bool = false
var _current_hp: int = 1

var _target_x: float = 0.0
var _idle_timer: float = 0.0
var _facing_right: bool = true
var _hold_timer: float = 0.0


func _ready() -> void:
	_current_hp = max_hp

	anim.play("fly")
	AudioManager.play_sound(appear_sound)

	# 使用 Spawner 的 TargetPosition 标记点的 X 坐标作为落点
	_target_x = target_landing_x
	_facing_right = _target_x > global_position.x
	anim.flip_h = not _facing_right

	# 给一个初始向上速度，形成抛物线轨迹
	velocity.y = ascend_v_speed

	hurtbox.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.animation_finished.connect(_on_anim_finished)

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += descend_gravity * delta

	match _state:
		State.DESCENDING:
			_update_descending(delta)
		State.IDLE:
			_update_idle(delta)
		State.THROW:
			_update_throw(delta)
		State.HOLD:
			_update_hold(delta)
		State.FLEEING:
			_update_fleeing(delta)

	move_and_slide()

	# 只有逃走状态下超出屏幕才消失
	if not screen_notifier.is_on_screen() and not _is_dead and _state == State.FLEEING:
		queue_free()


# ==================== DESCENDING：抛物线下坠 ====================

func _update_descending(_delta: float) -> void:
	# 持续面朝玩家
	_face_player()

	# 持续水平移向目标（确保不受碰撞/摩擦力影响）
	var dx = _target_x - global_position.x
	if abs(dx) > 10.0:
		velocity.x = signf(dx) * descend_h_speed
	else:
		velocity.x = 0.0

	# 落地 → 进入 idle
	if is_on_floor():
		velocity = Vector2.ZERO
		_state = State.IDLE
		_idle_timer = idle_duration
		anim.play("idle")


# ==================== IDLE：待机 ====================

func _update_idle(delta: float) -> void:
	velocity.x = 0.0
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_state = State.THROW
		# 参考 FlyingNinja：先发射投射物+音效，再播动画（音画同步）
		_spawn_dart()
		anim.play("throw")


# ==================== THROW：投掷 ====================

func _update_throw(_delta: float) -> void:
	velocity.x = 0.0
	# throw 动画只有 1 帧，由 animation_finished 触发投镖


func _spawn_dart() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()

	AudioManager.play_sound(throw_sound)

	var dart_scene = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
	var dart = dart_scene.instantiate() as FlyingNinjaDart
	dart.initialize(dir, dart_speed)
	dart.global_position = global_position + dir * 10
	get_tree().current_scene.add_child(dart)


# ==================== HOLD：投掷后保持姿势 ====================

func _update_hold(delta: float) -> void:
	velocity.x = 0.0
	_hold_timer -= delta
	if _hold_timer <= 0.0:
		# 保持结束 → 斜上方远离玩家逃跑
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_facing_right = global_position.x > player.global_position.x
		else:
			_facing_right = not _facing_right
		anim.flip_h = not _facing_right
		anim.play("fly")
		_state = State.FLEEING


# ==================== FLEEING：逃跑 ====================

func _update_fleeing(_delta: float) -> void:
	velocity.x = flee_h_speed * (1.0 if _facing_right else -1.0)
	velocity.y = flee_v_speed


# ==================== 动画回调 ====================

func _on_anim_finished() -> void:
	if _state == State.THROW:
		# throw 播完 → 保持投掷姿势 0.5s
		_state = State.HOLD
		_hold_timer = 0.5

	elif anim.animation == "death":
		queue_free()


# ==================== 面对玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		anim.flip_h = not should_face_right


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

	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)

	anim.play("death")


func _on_screen_exited() -> void:
	# 只有逃走状态下超出屏幕才消失
	if not _is_dead and _state == State.FLEEING:
		queue_free()
