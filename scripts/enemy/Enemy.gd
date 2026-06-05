# res://scripts/enemy/Enemy.gd
extends CharacterBody2D

class_name Enemy

# 默认属性（当没有配置资源时使用）
@export var max_hp: int = 1
@export var move_speed: float = 20.0
@export var patrol_distance: float = 100.0
@export var damage: int = 10

# 敌人数据资源（如果设置了，将覆盖上面的默认值）
@export var data: EnemyData

var start_position: Vector2
var direction: float = 1.0
var current_hp: int
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var hit_box: EnemyHitBox = $HitBox
@onready var floor_detector: RayCast2D = $FloorDetector

func _ready() -> void:
	# 如果关联了数据资源，就用资源里的值覆盖默认属性
	if data:
		max_hp = data.max_hp
		move_speed = data.move_speed
		patrol_distance = data.patrol_distance
		damage = data.damage
		# 同步 HitBox 的伤害
		if hit_box:
			hit_box.damage = data.damage
	else:
		# 没有资源时，也要把默认伤害同步给 HitBox
		if hit_box:
			hit_box.damage = damage

	current_hp = max_hp
	start_position = global_position

	# 连接受伤信号
	if hurt_box:
		hurt_box.took_damage.connect(_on_took_damage)

func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_update_floor_detector()

	if is_on_floor() and not floor_detector.is_colliding():
		direction *= -1.0

	if global_position.x > start_position.x + patrol_distance:
		direction = -1.0
	elif global_position.x < start_position.x - patrol_distance:
		direction = 1.0

	velocity.x = direction * move_speed
	velocity.y += 980 * delta

	sprite.flip_h = (direction < 0)

	if is_on_floor():
		sprite.play("walk")
	else:
		sprite.play("idle")

	move_and_slide()

func _update_floor_detector() -> void:
	floor_detector.target_position.x = abs(floor_detector.target_position.x) * direction
	floor_detector.force_raycast_update()

func _on_took_damage(amount: int) -> void:
	current_hp -= amount
	print("敌人受伤，剩余HP：", current_hp)
	if current_hp <= 0:
		die()

func die() -> void:
	if is_dead:
		return
	is_dead = true

	print("敌人死亡！")
	set_physics_process(false)
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
		await sprite.animation_finished
	queue_free()
