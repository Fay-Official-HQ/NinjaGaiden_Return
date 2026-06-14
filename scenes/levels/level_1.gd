extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.play_sound(&"bgml1")
	# 在运行时动态设置摄像机边界
	var cam = $Player/Camera2D
	cam.set_bounds(0, 4425)  # 左右边界

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
