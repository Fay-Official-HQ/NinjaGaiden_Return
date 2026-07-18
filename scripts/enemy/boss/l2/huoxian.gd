extends Area2D
class_name Huoxian

## 飞行速度
const FLY_SPEED: float = 1200.0
## 飞行总距离（从右穿过屏幕后消失）
const TRAVEL_DISTANCE: float = 1200.0

var _start_x: float = 0.0


func _ready() -> void:
	_start_x = global_position.x
	if has_node("FireballParticles"):
		$FireballParticles.restart()


func _process(delta: float) -> void:
	# 向右移动
	global_position.x += FLY_SPEED * delta

	# 飞行超过总距离后自销毁
	if abs(global_position.x - _start_x) >= TRAVEL_DISTANCE:
		queue_free()
