# res://scripts/ninjutsu/fireball_projectile.gd
extends Area2D
class_name FireballProjectile

@export var speed: float = 450.0
@export var lifetime: float = 1.5

var _direction: Vector2 = Vector2.DOWN
var _timer: float = 0.0

func _ready() -> void:
	_timer = lifetime
	area_entered.connect(_on_area_entered)

func set_direction(dir: Vector2) -> void:
	_direction = dir.normalized()

func _physics_process(delta: float) -> void:
	position += _direction * speed * delta
	_timer -= delta
	if _timer <= 0.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		if area.is_boss:
			area.take_damage(3)
			queue_free()
		else:
			area.take_damage(999)
