# res://scripts/player/states/FallState.gd
extends State

class_name FallState

var is_imbalance: bool = false
var regrab_cooldown: float = 0.0 # 新增：用于接收来自穿透状态的残余保护时间

func enter(msg: Dictionary = {}) -> void:
	is_imbalance = msg.get("imbalance", false)
	# 继承来自穿透状态传递过来的防回吸冷却时间
	regrab_cooldown = msg.get("regrab_cooldown", 0.0)
	
	if is_imbalance:
		player.animation.play("fall_imbalance")
	else:
		player.animation.play("fall")

func update(_delta: float) -> void:
	# 1. 触发空中攻击
	if Input.is_action_just_pressed("attack"):
		var move_dir = player.input.move_direction
		var air_imbalance = is_imbalance
		if move_dir != 0 and move_dir != player.facing_direction:
			air_imbalance = true
			
		state_machine.change_state(state_machine.get_node("AirAttackState"), {"imbalance": air_imbalance})
		return
		
	# 2. 触发空中忍术
	if Input.is_action_just_pressed("ninjutsu"):
		var move_dir = player.input.move_direction
		var air_imbalance = is_imbalance
		
		if move_dir != 0 and move_dir != player.facing_direction:
			air_imbalance = true
			
		state_machine.change_state(state_machine.get_node("AirNinjutsuState"), {"imbalance": air_imbalance})
		return

	# 触发真龙闪华必杀技（O键）
	if Input.is_action_just_pressed("finishing_move"):
		state_machine.change_state(state_machine.get_node("DragonFlashState"))
		return

	# 落地判定
	if player.is_on_floor():
		AudioManager.play_sound(&"tiaoyue")
		if player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)

func physics_update(delta: float) -> void:
	# 实时衰减残余的冷却保护时间
	if regrab_cooldown > 0:
		regrab_cooldown -= delta
	
	# 【核心修改】：只有当冷却时间结束（<=0）时，才允许天花板雷达探测抓取，彻底杜绝瞬间回吸
	if regrab_cooldown <= 0:
		var head_sensor = player.get_node("HeadSensor")
		if head_sensor.is_colliding():
			var collider = head_sensor.get_collider()
			if collider and collider.is_in_group("hanging_platform"):
				# 绝妙手感判定：只有当角色在下落(y>=0)、或者玩家主动按住“上”迎上去时，才触发悬挂。
				# 并且如果玩家按着“下”，绝对不抓（方便穿透平台）
				if (player.velocity.y >= 0 or Input.is_action_pressed("nav_up")) and not Input.is_action_pressed("nav_down"):
					state_machine.change_state(state_machine.get_node("HangState"))
					return
	
	# 【吸墙雷达】：下落中撞墙，且没有正在往墙外跳，立刻吸附
	if player.is_on_wall():
		if player.velocity.x * player.get_wall_normal().x <= 0:
			state_machine.change_state(state_machine.get_node("WallState"))
			return

	var move_dir = player.input.move_direction
	
	if Input.is_action_pressed("special_move"):
		state_machine.change_state(state_machine.get_node("SwordReadyState"))
		return
	
	# 下落惯性与失衡处理
	if is_imbalance:
		if move_dir != 0:
			if move_dir != player.facing_direction:
				player.velocity.x = move_dir * player.data.walk_speed * player.data.imbalance_speed_factor
			else:
				player.velocity.x = move_dir * player.data.walk_speed
		else:
			player.movement.stop()
	else:
		if move_dir != 0:
			if move_dir != player.facing_direction:
				is_imbalance = true
				player.animation.play("fall_imbalance")
				player.velocity.x = move_dir * player.data.walk_speed * player.data.imbalance_speed_factor
			else:
				player.movement.move(move_dir)
		else:
			player.movement.stop()
			
	player.move_and_slide()
