# res://scripts/enemy/Enemy.gd
extends CharacterBody2D

class_name Enemy

# 配置参数
@export var data: EnemyData
@export var patrol_points: PackedVector2Array = []

# 组件引用
@onready var state_machine: EnemyStateMachine = $StateMachine
@onready var movement: EnemyMovementComponent = $Components/EnemyMovementComponent
@onready var animation: AnimationComponent = $Components/AnimationComponent
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D

# 状态节点引用
@onready var patrol_state: PatrolState = $StateMachine/PatrolState
@onready var chase_state: ChaseState = $StateMachine/ChaseState
@onready var attack_state: AttackState = $StateMachine/AttackState
@onready var hurt_state: HurtState = $StateMachine/HurtState
@onready var death_state: DeathState = $StateMachine/DeathState

# 运行时数据
var health: int = 100
var facing_direction: float = 1.0
var is_alive: bool = true

func _ready() -> void:
	health = data.max_health
	movement.initialize(self)
	animation.initialize(animated_sprite)

func _physics_process(delta: float) -> void:
	if is_alive:
		state_machine.physics_update(delta)
		position = position.round()  # 像素完美对齐

func take_damage(damage: int, knockback_dir: Vector2 = Vector2.ZERO) -> void:
	if not is_alive: return
	
	health -= damage
	
	if health <= 0:
		die()
	else:
		state_machine.change_state(hurt_state, {
			"damage": damage,
			"knockback_dir": knockback_dir
		})

func die() -> void:
	is_alive = false
	state_machine.change_state(death_state)

func set_facing_direction(direction: float) -> void:
	facing_direction = 1.0 if direction > 0 else -1.0
	animation.flip_sprite(facing_direction)

func get_player_distance() -> float:
	var player = get_tree().get_first_node_in_group("player")
	if player:
		return global_position.distance_to(player.global_position)
	return INF
