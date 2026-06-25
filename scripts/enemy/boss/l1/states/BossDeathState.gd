extends BossState
class_name BossDeathState

func enter(_msg: Dictionary = {}) -> void:
	boss.die()
	var enemy_hitbox = boss.get_node_or_null("AttackRoot/EnemyHitBox")
	if enemy_hitbox:
		enemy_hitbox.set_deferred("monitoring", false)
		enemy_hitbox.set_deferred("monitorable", false)
	boss.animated_sprite.play("death")
	AudioManager.play_sound(&"disiwang")
	get_tree().create_timer(2.0).timeout.connect(_on_death_timer, CONNECT_ONE_SHOT)

func _on_death_timer() -> void:
	boss.visible = false
	await get_tree().create_timer(1.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	if boss.data and boss.data.defeat_next_scene != "":
		SceneTransition.fade_to_scene(boss.data.defeat_next_scene, boss.data.defeat_spawn_point, 2.0)
	await get_tree().create_timer(0.5).timeout
	boss.queue_free()
