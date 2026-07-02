extends ParallaxLayer

@export var scroll_speed: Vector2 = Vector2(-5.0, 0.0)

func _process(delta: float) -> void:
	motion_offset += scroll_speed * delta
