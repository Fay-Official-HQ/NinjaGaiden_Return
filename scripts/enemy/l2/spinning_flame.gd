extends Area2D
class_name SpinningFlame

var _velocity: Vector2
var _upward_strength: float = 400.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.play("fly")


func initialize(direction: Vector2, speed: float, upward_strength: float = 200.0, initial_vy: float = 0.0) -> void:
	_velocity = direction * speed
	_velocity.y += initial_vy
	_upward_strength = upward_strength


func _process(delta: float) -> void:
	_velocity.y -= _upward_strength * delta
	global_position += _velocity * delta


func _on_screen_exited() -> void:
	queue_free()
