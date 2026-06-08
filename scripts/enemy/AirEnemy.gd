# res://scripts/enemy/AirEnemy.gd
extends CharacterBody2D

class_name AirEnemy

# 默认属性（当没有配置资源时使用）
@export var max_hp: int = 30
@export var move_speed: float = 50.0
@export var patrol_distance: float = 100.0
@export var damage: int = 10

# 飞行模式：勾选后不受重力，固定在空中
@export var is_flying: bool = false

# 敌人数据资源（如果设置了，将覆盖上面的默认值）
@export var data: EnemyData

var start_position: Vector2
var direction: float = 1.0
var current_hp: int
var is_dead: bool = false

@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var hit_box: EnemyHitBox = $HitBox

func _ready() -> void:
	# 如果关联了数据资源，就用资源里的值覆盖默认属性
	if data:
		max_hp = data.max_hp
		move_speed = data.move_speed
		patrol_distance = data.patrol_distance
		damage = data.damage
		# 注意：飞行状态也可以放在 EnemyData 里，但暂时先用手动勾选
		if hit_box:
			hit_box.damage = data.damage
	else:
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

	# 水平巡逻
	velocity.x = direction * move_speed

	# 飞行敌人：无重力，竖直速度保持0
	if is_flying:
		velocity.y = 0.0
	else:
		# 地面敌人：正常施加重力
		velocity.y += 980 * delta

	# 巡逻边界回头
	if global_position.x > start_position.x + patrol_distance:
		direction = -1.0
	elif global_position.x < start_position.x - patrol_distance:
		direction = 1.0

	sprite.flip_h = (direction < 0)

	# 动画处理
	if is_flying:
		# 飞行敌人直接播放 walk 动画（或你可以改成专门的 "fly" 动画）
		sprite.play("walk")
	else:
		if is_on_floor():
			sprite.play("walk")
		else:
			sprite.play("idle")

	move_and_slide()

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
	AudioManager.play_sound(&"disiwang")
	set_physics_process(false)
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	if sprite.sprite_frames.has_animation("die"):
		sprite.play("die")
		await sprite.animation_finished
	queue_free()
