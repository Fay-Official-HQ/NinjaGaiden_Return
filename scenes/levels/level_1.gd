extends Node2D


func _ready() -> void:
	AudioManager.play_sound(&"bgml1")

	# 根据入口点定位玩家
	_place_player_at_entry()

	# 在运行时动态设置摄像机边界
	var cam = $Player/Camera2D
	cam.set_bounds(-0, 4425)  # 左右边界


# ============================================================
#  入口点定位：将玩家传送到对应 Marker2D 的位置
# ============================================================
# 使用方式（在切换关卡前设置）：
#   LevelManager.spawn_point = "entry_left"   # 从左入口进入
#   LevelManager.spawn_point = "entry_right"  # 从右入口进入
#   get_tree().change_scene_to_file("res://...")
#
# 如果没设置或者找不到对应标记，玩家保持场景编辑器中的默认位置
# ============================================================

func _place_player_at_entry() -> void:
	var entry_name = LevelManager.spawn_point
	# 读取后立即重置为默认值，确保下次进入时不会重复使用上次的入口点
	LevelManager.spawn_point = "default"

	var entry = get_node_or_null(entry_name)
	if entry and entry is Marker2D:
		$Player.global_position = entry.global_position
		print("玩家从入口 %s 进入" % entry_name)
