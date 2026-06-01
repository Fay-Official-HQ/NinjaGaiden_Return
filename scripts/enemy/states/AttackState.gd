# res://scripts/enemy/states/AttackState.gd
extends EnemyState

var attack_timer: float = 0.0
var is_attacking: bool = false

func enter(msg: Dictionary = {}) -> void:
	enemy.animation.play("attack")
	enemy.movement.stop()
	attack_timer = enemy.data.attack_cooldown
	is_attacking = true
	
	# 播放攻击动画时开启HitBox
	var hit_box = enemy.get_node_or_null("AttackHitBox")
	if hit_box:
		hit_box.monitoring = true

func update(delta: float) -> void:
	if is_attacking:
		# 动画结束后关闭HitBox
		if not enemy.animation.is_playing():
			is_attacking = false
			var hit_box = enemy.get_node_or_null("AttackHitBox")
			if hit_box:
				hit_box.monitoring = false
	else:
		attack_timer -= delta
		if attack_timer <= 0:
			state_machine.change_state(enemy.chase_state)
