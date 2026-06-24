extends BossState
class_name BossDeathState

func enter(_msg: Dictionary = {}) -> void:
	boss.die()
	boss.animated_sprite.play("death")
	AudioManager.play_sound(&"disiwang")
	boss.animated_sprite.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)

func _on_death_finished() -> void:
	boss.visible = false
	await get_tree().create_timer(1.5).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	if boss.data.defeat_next_scene != "":
		SceneTransition.fade_to_scene(boss.data.defeat_next_scene, boss.data.defeat_spawn_point, 2.0)
	await get_tree().create_timer(0.5).timeout
	boss.queue_free()
