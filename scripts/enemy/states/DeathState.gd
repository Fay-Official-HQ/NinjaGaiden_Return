# res://scripts/enemy/states/DeathState.gd
extends EnemyState

var death_timer: float = 1.0

func enter(msg: Dictionary = {}) -> void:
	enemy.animation.play("death")
	enemy.movement.stop()
	
	# 禁用碰撞
	enemy.set_collision_layer(0)
	enemy.set_collision_mask(0)

func update(delta: float) -> void:
	death_timer -= delta
	
	if death_timer <= 0 or not enemy.animation.is_playing():
		enemy.queue_free()
