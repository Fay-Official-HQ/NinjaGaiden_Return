extends CharacterBody2D
class_name FemalePatrol

# ==================== 导出调试参数 ====================

## 血量
@export var max_hp: int = 1
## 巡逻移动速度（像素/秒）
@export var move_speed: float = 30.0
## 接触伤害值
@export var contact_damage: int = 1
## 巡逻半径（从出生点算起）
@export var patrol_distance: float = 100.0
## 重力加速度
@export var gravity: float = 980.0
## 死亡动画名称
@export var death_anim: String = "death"
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 初始面朝方向
@export var initial_facing_right: bool = true

# ==================== 节点引用 ====================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect: RayCast2D = $WallDetect

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1
var _start_position: Vector2


func _ready() -> void:
	facing_right = initial_facing_right
	anim.flip_h = not facing_right
	current_hp = max_hp
	_start_position = global_position

	hitbox.collision_mask = 1
	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	hurtbox.took_damage.connect(_on_took_damage)


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_check_turn()
	velocity.x = move_speed * (1.0 if facing_right else -1.0)
	move_and_slide()
	_update_animation()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


func _check_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left

	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)
		return

	var distance = global_position.x - _start_position.x
	if distance > patrol_distance:
		_set_facing(false)
	elif distance < -patrol_distance:
		_set_facing(true)


func _update_animation() -> void:
	if is_on_floor():
		if anim.sprite_frames and anim.sprite_frames.has_animation("walk"):
			anim.play("walk")
	else:
		if anim.sprite_frames and anim.sprite_frames.has_animation("idle"):
			anim.play("idle")


func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()


func _die() -> void:
	is_dead = true

	AudioManager.play_sound(death_sound)

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)

	if anim.sprite_frames and anim.sprite_frames.has_animation(death_anim):
		anim.play(death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right
