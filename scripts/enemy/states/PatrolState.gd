# res://scripts/enemy/states/PatrolState.gd
extends EnemyState

var current_point_index: int = 0
var pause_timer: float = 0.0
var is_paused: bool = false

func enter(msg: Dictionary = {}) -> void:
	enemy.animation.play("walk")
	current_point_index = 0
	pause_timer = 0.0
	is_paused = false

func physics_update(delta: float) -> void:
	# 检测玩家是否在范围内
	if enemy.get_player_distance() < enemy.data.detection_range:
		state_machine.change_state(enemy.chase_state)
		return
	
	# 巡逻逻辑
	if enemy.patrol_points.size() == 0:
		# 没有巡逻点时随机移动
		random_walk(delta)
	else:
		patrol_between_points(delta)

func patrol_between_points(delta: float) -> void:
	if is_paused:
		pause_timer -= delta
		enemy.movement.stop()
		enemy.animation.play("idle")
		
		if pause_timer <= 0:
			is_paused = false
			enemy.animation.play("walk")
		return
	
	var target_point = enemy.patrol_points[current_point_index]
	var direction = (target_point - enemy.position).normalized()
	
	# 到达目标点
	if enemy.position.distance_to(target_point) < 5:
		current_point_index = (current_point_index + 1) % enemy.patrol_points.size()
		pause_timer = enemy.data.patrol_pause_time
		is_paused = true
		return
	
	enemy.set_facing_direction(direction.x)
	enemy.movement.move(direction * enemy.data.patrol_speed)

func random_walk(delta: float) -> void:
	# 简单随机移动
	if randi() % 100 < 2:
		enemy.set_facing_direction(1 if randi() % 2 == 0 else -1)
	
	enemy.movement.move(Vector2(enemy.facing_direction, 0) * enemy.data.patrol_speed)
	
	# 碰到墙壁时转向
	if enemy.movement.is_wall_colliding():
		enemy.set_facing_direction(-enemy.facing_direction)
