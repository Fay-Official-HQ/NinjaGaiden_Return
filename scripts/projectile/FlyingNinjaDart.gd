extends Area2D
class_name FlyingNinjaDart

## 飞天忍者的飞镖——不可摧毁，飞出屏幕即消失

var _direction: Vector2
var _speed: float

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)


func initialize(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	# 直接 $ 取子节点（_ready 尚未调用，@onready 不可用）
	$AnimatedSprite2D.flip_h = _direction.x < 0


func _process(delta: float) -> void:
	global_position += _direction * _speed * delta


func _on_screen_exited() -> void:
	queue_free()
