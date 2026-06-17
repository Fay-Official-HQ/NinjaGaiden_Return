extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	AudioManager.play_sound(&"bgml1")
	# 在运行时动态设置摄像机边界
	var cam = $Player/Camera2D
	cam.set_bounds(-5000, 160)  # 左右边界
	cam.offset.y = -150  # 负值 = 摄像机画面上移 = 玩家在屏幕中显得更低

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
