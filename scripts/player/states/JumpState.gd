# res://scripts/player/states/JumpState.gd
extends State

class_name JumpState

var is_wall_jump: bool = false
var wall_jump_lockout_timer: float = 0.0

func enter(msg: Dictionary = {}) -> void:
	player.animation.play("jump")
	AudioManager.play_sound(&"tiaoyue")
	is_wall_jump = msg.get("wall_jump", false)
	if is_wall_jump:
		# 给予 0.15 秒的向外爆发力保护
		wall_jump_lockout_timer = 0.15
	else:
		player.movement.jump()

func update(_delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		var move_dir = player.input.move_direction
		var air_imbalance = false
		if move_dir != 0 and move_dir != player.facing_direction:
			air_imbalance = true
		state_machine.change_state(state_machine.get_node("AirAttackState"), {"imbalance": air_imbalance})
		return
		
	if Input.is_action_just_pressed("ninjutsu"):
		var move_dir = player.input.move_direction
		var air_imbalance = false
		if move_dir != 0 and move_dir != player.facing_direction:
			air_imbalance = true
		state_machine.change_state(state_machine.get_node("AirNinjutsuState"), {"imbalance": air_imbalance})
		return

	# 触发真龙闪华必杀技（O键）
	if Input.is_action_just_pressed("finishing_move"):
		state_machine.change_state(state_machine.get_node("DragonFlashState"))
		return

	if player.movement.is_falling():
		state_machine.change_state(player.fall_state, {"imbalance": false})
		return

func physics_update(delta: float) -> void:
	# 【天花板吊台雷达】
	var head_sensor = player.get_node("HeadSensor")
	if head_sensor.is_colliding():
		var collider = head_sensor.get_collider()
		if collider.is_in_group("hanging_platform"):
			# 绝妙手感判定：只有当角色在下落(y>=0)、或者玩家主动按住“上”迎上去时，才触发悬挂。
			# 并且如果玩家按着“下”，绝对不抓（方便穿透平台）
			if (player.velocity.y >= 0 or Input.is_action_pressed("nav_up")) and not Input.is_action_pressed("nav_down"):
				state_machine.change_state(state_machine.get_node("HangState"))
				return
	
	if player.is_on_wall() and not _is_on_wall_blocker():
		if player.velocity.x * player.get_wall_normal().x <= 0:
			state_machine.change_state(state_machine.get_node("WallState"))
			return

	var move_dir = player.input.move_direction

	if Input.is_action_pressed("special_move"):
		state_machine.change_state(state_machine.get_node("SwordReadyState"))
		return

	# 【核心修复：智能单向硬直解除】
	if is_wall_jump and wall_jump_lockout_timer > 0:
		wall_jump_lockout_timer -= delta
		
		# 侦测：如果玩家当前按下的方向，是背对角色的面朝方向（说明想往回墙的方向靠）
		if move_dir != 0 and move_dir != player.facing_direction:
			# 瞬间强行清零硬直时间！
			wall_jump_lockout_timer = 0.0
		else:
			# 否则，继续保护爆发惯性，不执行后续常规移动
			player.move_and_slide()
			return

	# 空中转身失衡机制
	if move_dir != 0:
		if move_dir != player.facing_direction:
			player.velocity.x = move_dir * player.data.walk_speed * player.data.imbalance_speed_factor
			state_machine.change_state(player.fall_state, {"imbalance": true})
			player.move_and_slide()
			return
		else:
			player.movement.move(move_dir)
	else:
		player.movement.stop()
		
	player.move_and_slide()


# 检测当前贴墙的碰撞体是否属于 wall_blocker 组（阻挡物不触发攀爬）
func _is_on_wall_blocker() -> bool:
	for i in player.get_slide_collision_count():
		var col = player.get_slide_collision(i)
		if col and col.get_collider() and col.get_collider().is_in_group("wall_blocker"):
			return true
	return false
