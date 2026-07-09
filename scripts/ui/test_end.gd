extends Node2D

@onready var label: Label

var _dot_count: int = 0
var _timer: float = 0.0

const DOT_INTERVAL: float = 0.65
const MAX_DOTS: int = 6

func _ready() -> void:
	SceneTransition.clear_overlay_safe()
	label = find_child("dian", true, false) as Label
	if not is_instance_valid(label):
		push_error("test_end.gd: 未找到 dian 节点")
		return
	label.text = ""
	UIManager.visible = false
	AudioManager.play_sound(&"end_bad")

func _process(delta: float) -> void:
	if not is_instance_valid(label):
		return
	_timer += delta
	if _timer >= DOT_INTERVAL:
		_timer -= DOT_INTERVAL
		_dot_count += 1
		if _dot_count > MAX_DOTS:
			_dot_count = 0
		label.text = ""
		for i in _dot_count:
			label.text += "."
