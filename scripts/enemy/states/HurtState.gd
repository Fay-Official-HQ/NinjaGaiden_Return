# res://scripts/enemy/states/HurtState.gd
extends EnemyState

var knockback_force: Vector2 = Vector2.ZERO
var invulnerable_timer: float = 0.5

func enter(msg: Dictionary = {}) -> void:
	enemy.animation.play("hurt")
	enemy.movement.stop()
	
	# 应用击退
	var knockback_dir = msg.get("knockback_dir", Vector2(-enemy.facing_direction, -0.5))
	knockback_force = knockback_dir * 100
	
	invulnerable_timer = 0.5

func physics_update(delta: float) -> void:
	invulnerable_timer -= delta
	
	# 应用击退
	if knockback_force.length() > 0:
		enemy.movement.apply_impulse(knockback_force)
		knockback_force *= 0.9  # 衰减
		
	if invulnerable_timer <= 0 and not enemy.animation.is_playing():
		# 回到追击或巡逻状态
		if enemy.get_player_distance() < enemy.data.detection_range:
			state_machine.change_state(enemy.chase_state)
		else:
			state_machine.change_state(enemy.patrol_state)
