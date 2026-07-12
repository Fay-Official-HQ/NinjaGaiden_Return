# res://scenes/levels/l2/cloud_layer2_2.gd
extends ParallaxLayer

var _offset: float = 0.0


func _process(delta: float) -> void:
	_offset += 20.0 * delta

	motion_offset.x = -_offset
