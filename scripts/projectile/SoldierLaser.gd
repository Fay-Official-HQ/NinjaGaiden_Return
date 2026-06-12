extends Area2D
class_name SoldierLaser

## 士兵激光——速度极快，不可摧毁，飞出屏幕即消失

var _direction: float = 1.0
var _speed: float

@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)


func initialize(dir: float, speed: float) -> void:
	_direction = dir
	_speed = speed
	$Sprite2D.flip_h = dir < 0


func _process(delta: float) -> void:
	global_position.x += _direction * _speed * delta


func _on_screen_exited() -> void:
	queue_free()
