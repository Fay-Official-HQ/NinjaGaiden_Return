# res://scripts/enemy/boss/l3/ninjutsu/boss_boomerang.gd
## BOSS 回旋镖忍术弹体（以 BOSS 为锚点水平弹簧回拉）
extends Area2D
class_name BossBoomerang

@export var throw_speed: float = 1500.0
@export var spring_stiffness: float = 50.0
@export var damping: float = 0.96
@export var min_amplitude: float = 8.0
@export var lifetime: float = 3.0

var boss_ref: Node2D
var base_direction: Vector2
var _velocity: Vector2 = Vector2.ZERO
var life_timer: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	life_timer = lifetime

func initialize(caster: Node2D, dir: Vector2) -> void:
	boss_ref = caster
	base_direction = dir.normalized()
	_velocity = base_direction * throw_speed
	global_position = caster.global_position + base_direction * 10.0

func _physics_process(delta: float) -> void:
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return
	if not boss_ref:
		return

	var offset = global_position - boss_ref.global_position
	var acceleration = -spring_stiffness * offset
	_velocity += acceleration * delta
	_velocity *= damping
	global_position += _velocity * delta

	if offset.length() < min_amplitude and _velocity.length() < 50.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(1)
