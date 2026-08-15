extends Area2D
class_name FirePhoenix

## 横向投射物：不可被攻击摧毁，也不能被格挡

var _direction: float = 1.0
var _speed: float = 300.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)


func initialize(dir: float, speed: float) -> void:
	_direction = dir
	_speed = speed
	anim.flip_h = dir < 0
	anim.play("flying")


func _process(delta: float) -> void:
	global_position.x += _direction * _speed * delta


func _on_screen_exited() -> void:
	queue_free()
