extends Label

@export var blink_speed: float = 0.5  # 闪烁速度（秒）

func _ready():
	# 开始闪烁
	start_blink()

func start_blink():
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(self, "modulate:a", 0.0, blink_speed)
	tween.tween_property(self, "modulate:a", 1.0, blink_speed)

func stop_blink():
	# 停止所有动画并恢复完全可见
	var tween = get_tree().create_tween()
	tween.kill()
	modulate.a = 1.0
