extends Node2D


func _ready() -> void:
	SceneTransition.clear_overlay_safe()
	AudioManager.play_sound(&"bgml1")

	# 根据入口点定位玩家
	_place_player_at_entry()

	# 在运行时动态设置摄像机边界
	var cam = $Player/Camera2D
	cam.set_bounds(-4100, 160)  # 左右边界
	cam.offset.y = -150  # 负值 = 摄像机画面上移 = 玩家在屏幕中显得更低



# ============================================================
#  入口点定位：将玩家传送到对应 Marker2D 的位置
# ============================================================
# 使用方式：
#   LevelManager.spawn_point = "entry_left"
#   get_tree().change_scene_to_file("res://...")
# ============================================================

func _place_player_at_entry() -> void:
	var entry_name = LevelManager.spawn_point
	LevelManager.spawn_point = "default"

	var entry = get_node_or_null(entry_name)
	if entry and entry is Marker2D:
		$Player.global_position = entry.global_position
		print("玩家从入口 %s 进入" % entry_name)
