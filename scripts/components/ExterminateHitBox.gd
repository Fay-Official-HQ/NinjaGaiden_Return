extends AttackHitBox
class_name ExterminateHitBox

var _normal_shape_size: Vector2
var _normal_shape_pos: Vector2
var _crouch_shape_size: Vector2
var _crouch_shape_pos: Vector2

func _ready() -> void:
	super()
	var shape_node = $CollisionShape2D
	if shape_node and shape_node.shape:
		_normal_shape_size = shape_node.shape.size
		_normal_shape_pos = shape_node.position
		_crouch_shape_size = Vector2(_normal_shape_size.x, _normal_shape_size.y * 0.7)
		_crouch_shape_pos = Vector2(_normal_shape_pos.x, _normal_shape_pos.y + _normal_shape_size.y * 0.15)

func set_crouch(enabled: bool) -> void:
	var shape_node = $CollisionShape2D
	if not shape_node or not shape_node.shape:
		return
	if enabled:
		shape_node.shape.size = _crouch_shape_size
		shape_node.position = _crouch_shape_pos
	else:
		shape_node.shape.size = _normal_shape_size
		shape_node.position = _normal_shape_pos
