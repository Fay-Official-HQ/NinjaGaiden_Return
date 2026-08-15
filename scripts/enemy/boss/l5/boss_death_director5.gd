extends BossDeathDirector
class_name BossDeathDirector_5

func _end_level() -> void:
	_is_playing = false
	is_death_playing = false

	if _boss:
		_boss.queue_free()
		_boss = null

	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	LevelManager.spawn_point = "default"

	# 前往第三章过场动画
	Cutscene.target_chapter = 5
	get_tree().change_scene_to_file("res://scenes/ui/TestEnd.tscn")
