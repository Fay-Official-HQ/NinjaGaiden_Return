extends CanvasLayer

func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	UIManager.visible = false

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pass"):
		get_tree().change_scene_to_file("res://scenes/levels/Level_1.tscn")

func _exit_tree() -> void:
	UIManager.visible = true
