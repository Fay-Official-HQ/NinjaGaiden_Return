extends ParallaxLayer

var _offset: float = 0.0


func _process(delta: float) -> void:
	_offset += 5.0 * delta

	# motion_offset 是 ParallaxLayer 官方滚动接口
	# 它会自动与 motion_scale 视差叠加、被 motion_mirroring 循环平铺
	motion_offset.x = -_offset
