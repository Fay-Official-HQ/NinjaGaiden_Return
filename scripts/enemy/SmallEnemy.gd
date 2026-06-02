# res://scripts/enemy/SmallEnemy.gd
extends CharacterBody2D

class_name SmallEnemy

@export var move_speed: float = 10
@export var patrol_distance: float = 100.0
@export var max_hp: int = 1

var start_position: Vector2
var direction: float = 1.0
var current_hp: int

@onready var sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var hit_box: EnemyHitBox = $HitBox   # 改这里

func _ready() -> void:
	start_position = global_position
	current_hp = max_hp

	if hurt_box:
		hurt_box.took_damage.connect(_on_took_damage)

func _physics_process(delta: float) -> void:
	velocity.x = direction * move_speed
	velocity.y += 980 * delta

	if global_position.x > start_position.x + patrol_distance:
		direction = -1.0
	elif global_position.x < start_position.x - patrol_distance:
		direction = 1.0

	sprite.flip_h = (direction < 0)

	if is_on_floor():
		sprite.play("walk")
	else:
		sprite.play("idle")

	move_and_slide()

func _on_took_damage(damage: int) -> void:
	current_hp -= damage
	print("敌人受伤，剩余HP：", current_hp)
	if current_hp <= 0:
		die()

func die() -> void:
	print("敌人死亡！")
	queue_free()
