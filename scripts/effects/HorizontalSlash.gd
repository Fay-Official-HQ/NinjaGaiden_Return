extends Node2D

@export var slash_width: float = 600.0
@export var slash_height: float = 2.0
@export var slash_color: Color = Color(1, 0.15, 0.15, 0.95)
@export var duration: float = 0.3

var _start_pos: Vector2
var _end_pos: Vector2
var _start_time: int

func _ready():
	process_mode = PROCESS_MODE_ALWAYS
	$SlashLine.modulate = slash_color
	$SlashLine.scale = Vector2(slash_width, slash_height)

	var angle = randf_range(0, TAU)
	rotation = angle
	var dir = Vector2.RIGHT.rotated(angle)

	_start_pos = position - dir * slash_width * 0.5
	_end_pos = position + dir * slash_width * 1.5
	_start_time = Time.get_ticks_usec()

func _process(_delta: float) -> void:
	var elapsed = (Time.get_ticks_usec() - _start_time) / 1000000.0
	var t = min(elapsed / duration, 1.0)
	position = _start_pos.lerp(_end_pos, t)
	$SlashLine.modulate.a = lerpf(slash_color.a, 0.0, min(t / 0.8, 1.0))
	if t >= 1.0:
		queue_free()
