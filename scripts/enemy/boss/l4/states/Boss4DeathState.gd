extends BossState
class_name Boss4DeathState

## ============================================================
## BOSS4 死亡状态
## 女人身体（AnimatedSprite2D）和骷髅头（HeadAnimatedSprite2D）
## 分别播放各自的死亡动画，显示死亡特效，播放死亡音效
## （碰撞框的关闭由 boss_4.gd 的 die() 在死亡序列恢复阶段完成）
## ============================================================

func enter(msg: Dictionary = {}) -> void:
	boss.is_invincible = true
	boss.velocity = Vector2.ZERO

	# 女人身体播放死亡动画
	if boss.animated_sprite and boss.animated_sprite.sprite_frames \
			and boss.animated_sprite.sprite_frames.has_animation("dead"):
		boss.animated_sprite.play("dead")

	# 骷髅头播放死亡动画
	var head = boss.get_node_or_null("Visual/HeadAnimatedSprite2D") as AnimatedSprite2D
	if head and head.sprite_frames and head.sprite_frames.has_animation("dead"):
		head.play("dead")

	# 显示死亡特效（bosssiwang）
	var death_effect = boss.get_node_or_null("Visual/DeathEffectAnim") as AnimatedSprite2D
	if death_effect:
		death_effect.visible = true
		death_effect.play("default")

	# 播放死亡音效（数据驱动）
	var data: BossData_4 = boss.data as BossData_4
	var sound: StringName = data.death_sound if data else &"disiwang"
	AudioManager.play_sound(sound)

	# 无导演（未走红黑剪影流程）时使用兜底死亡流程
	var director = msg.get("director", null)
	if not director:
		_legacy_death()


func physics_update(_delta: float) -> void:
	boss.velocity = Vector2.ZERO


func exit() -> void:
	boss.is_invincible = false


## 兜底死亡：关闭所有碰撞框 → 隐藏 → 转场 → 销毁
func _legacy_death() -> void:
	boss.die()
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
