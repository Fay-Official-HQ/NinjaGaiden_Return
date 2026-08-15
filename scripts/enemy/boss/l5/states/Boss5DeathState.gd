extends BossState
class_name Boss5DeathState

func enter(_msg: Dictionary = {}) -> void:
	# 死亡演出由 BossDeathDirector_5 统一控制，此处仅播放死亡动画与专属死亡特效
	boss.animated_sprite.play("death")
	var effect := boss.get_node_or_null("Visual/DeathEffectAnim") as AnimatedSprite2D
	if effect:
		effect.visible = true
		effect.play()
