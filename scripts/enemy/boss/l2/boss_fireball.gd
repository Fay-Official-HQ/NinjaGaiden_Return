extends Area2D
class_name BossFireball

var _direction: Vector2
var _speed: float

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)
	if has_node("FireballParticles"):
		$FireballParticles.restart()


func initialize(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	$AnimatedSprite2D.flip_h = _direction.x < 0


func _process(delta: float) -> void:
	global_position += _direction * _speed * delta


func _on_screen_exited() -> void:
	queue_free()
