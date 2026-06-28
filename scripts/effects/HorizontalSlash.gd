extends Node2D

@export var slash_width: float = 600.0
@export var slash_height: float = 2.0
@export var slash_color: Color = Color(1, 0.15, 0.15, 0.95)
@export var duration: float = 0.3

var _direction: float = 1.0
var _start_x: float
var _end_x: float
var _start_time: int

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	$SlashLine.modulate = slash_color
	$SlashLine.scale = Vector2(slash_width, slash_height)

	position.x -= _direction * slash_width * 0.5
	_start_x = position.x
	_end_x = _start_x + _direction * slash_width * 1.5
	_start_time = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var elapsed = (Time.get_ticks_usec() - _start_time) / 1000000.0
	var t = min(elapsed / duration, 1.0)
	position.x = lerpf(_start_x, _end_x, t)
	$SlashLine.modulate.a = lerpf(slash_color.a, 0.0, min(t / 0.8, 1.0))
	if t >= 1.0:
		queue_free()
