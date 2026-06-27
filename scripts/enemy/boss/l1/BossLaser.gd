extends Area2D
class_name BossLaser

const SPEED: float = 1500.0
const MAX_LENGTH: float = 2000.0
const MAX_LIFETIME: float = 5.0   # 最大存活秒数，防止激光飞出屏幕后无限飞行
const HEIGHT: float = 20.0
const TAIL_IMAGE_WIDTH: float = 30.0

var direction: float = 1.0
var _current_length: float = 0.0
var _finished: bool = false
var _life: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $EnemyHitBox/CollisionShape2D

func initialize(dir: float, from_pos: Vector2) -> void:
	direction = dir
	# X: 水平偏移（调大=更靠前），Y: 垂直偏移（负=抬高，正=降低）
	global_position = from_pos + Vector2(dir * 20.0, 0.0)

func _ready() -> void:
	sprite.centered = false
	sprite.position.y = -HEIGHT / 2.0

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= MAX_LIFETIME:
		queue_free()
		return
	if _finished:
		global_position.x += direction * SPEED * delta
		if abs(global_position.x) > 4000:
			queue_free()
		return

	_current_length += SPEED * delta
	if _current_length >= MAX_LENGTH:
		_current_length = MAX_LENGTH
		_finished = true

	sprite.scale.x = _current_length / TAIL_IMAGE_WIDTH * direction
	sprite.position.x = 0

	collision_shape.shape.size = Vector2(_current_length, HEIGHT)
	collision_shape.position.x = _current_length / 2.0 * direction
