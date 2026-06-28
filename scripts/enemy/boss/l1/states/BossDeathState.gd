extends BossState
class_name BossDeathState


func enter(msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.is_invincible = true
	boss.collision_layer = 0
	boss.collision_mask = 0
	if "ignore_gravity" in boss:
		boss.ignore_gravity = true

	boss.animated_sprite.play("death")
	var death_effect = boss.get_node_or_null("Visual/DeathEffectAnim")
	if death_effect:
		death_effect.visible = true
		death_effect.play("default")

	var director = msg.get("director", null)
	if not director:
		_legacy_death()


func physics_update(_delta: float) -> void:
	boss.velocity = Vector2.ZERO


func exit() -> void:
	boss.is_invincible = false


func _legacy_death() -> void:
	boss.animated_sprite.play("death")
	AudioManager.play_sound(&"disiwang")
	get_tree().create_timer(2.0).timeout.connect(_on_legacy_death_timer, CONNECT_ONE_SHOT)


func _on_legacy_death_timer() -> void:
	boss.visible = false
	await get_tree().create_timer(1.0).timeout
	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	if boss.data and boss.data.defeat_next_scene != "":
		SceneTransition.fade_to_scene(boss.data.defeat_next_scene, boss.data.defeat_spawn_point, 2.0)
	await get_tree().create_timer(0.5).timeout
	boss.queue_free()
