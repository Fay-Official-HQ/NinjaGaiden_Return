# res://scripts/enemy/states/ChaseState.gd
extends EnemyState

func enter(msg: Dictionary = {}) -> void:
	enemy.animation.play("walk")

func physics_update(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		state_machine.change_state(enemy.patrol_state)
		return
	
	# 超出检测范围返回巡逻
	var distance = enemy.global_position.distance_to(player.global_position)
	if distance > enemy.data.detection_range:
		state_machine.change_state(enemy.patrol_state)
		return
	
	# 攻击范围内攻击
	if distance < enemy.data.attack_range:
		state_machine.change_state(enemy.attack_state)
		return
	
	# 追击玩家
	var direction = (player.global_position - enemy.global_position).normalized()
	enemy.set_facing_direction(direction.x)
	enemy.movement.move(direction * enemy.data.chase_speed)
