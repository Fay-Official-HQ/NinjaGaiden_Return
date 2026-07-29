# res://scripts/enemy/boss/l3/ninjutsu/boss_edge_blade.gd
## BOSS 棱刃忍术弹体（以 BOSS 为锚点垂直弹簧回拉）
extends Area2D
class_name BossEdgeBlade

@export var initial_direction: Vector2 = Vector2.UP
@export var initial_speed: float = 1000.0
@export var spring_stiffness: float = 50.0
@export var damping: float = 0.96
@export var min_amplitude: float = 10.0
@export var lifetime: float = 3.0

var boss_ref: Node2D
var _velocity_y: float = 0.0
var life_timer: float = 0.0
var _initial_dir_sign: float = 1.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	life_timer = lifetime

func initialize(caster: Node2D, dir: Vector2) -> void:
	boss_ref = caster
	var d = dir.normalized()
	_initial_dir_sign = sign(d.y)
	_velocity_y = d.y * initial_speed
	global_position = caster.global_position + d * 10.0

func _physics_process(delta: float) -> void:
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return
	if not boss_ref:
		return

	var offset_y = global_position.y - boss_ref.global_position.y
	var acceleration_y = -spring_stiffness * offset_y
	_velocity_y += acceleration_y * delta
	_velocity_y *= damping
	global_position.y += _velocity_y * delta
	global_position.x = boss_ref.global_position.x

	if abs(offset_y) < min_amplitude and abs(_velocity_y) < 40.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(1)
