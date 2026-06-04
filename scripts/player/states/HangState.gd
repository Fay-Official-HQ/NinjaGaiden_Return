# res://scripts/player/states/HangState.gd
extends State

class_name HangState

@export var hang_climb_speed: float = 80.0
@export var hang_y_offset: float = 12 # 控制抓取时角色视觉高低，可根据模型微调

var is_casting: bool = false

func enter(_msg: Dictionary = {}) -> void:
	is_casting = false
	player.velocity = Vector2.ZERO
	player.animation.play("hang_idle")
	
	# 抓取瞬间：强制刷新射线，将角色精准吸附在平台下沿
	var sensor = player.get_node("HeadSensor") as RayCast2D
	sensor.force_raycast_update()
	
	if sensor.is_colliding():
		var collision_point = sensor.get_collision_point()
		player.global_position.y = collision_point.y + hang_y_offset

func update(_delta: float) -> void:
	# --- 忍术结算 ---
	if is_casting:
		var sprite = player.animation.sprite
		if sprite.animation == "hang_ninjutsu" and not sprite.is_playing():
			is_casting = false
			player.animation.play("hang_idle")
		return

	# --- 释放悬挂专属忍术 ---
	if Input.is_action_just_pressed("ninjutsu"):
		is_casting = true
		player.velocity.x = 0
		player.animation.play("hang_ninjutsu")
		player.ninjutsu.cast_ninjutsu()
		return

	# --- 退出方式 1：向下脱离 ---
	# 完美复用我们刚才写好的“穿透状态”，让它代劳处理安全下落！
	#if Input.is_action_pressed("nav_down") and Input.is_action_just_pressed("jump"):
		#state_machine.change_state(state_machine.get_node("PlatformDropState"))
		#player.input.consume_jump()
		#return
	if Input.is_action_pressed("nav_down") and Input.is_action_just_pressed("jump"):
		# 【核心修改】：传递 0.25 秒的防误触冷却时间，给角色争取脱离吊台的物理时间
		state_machine.change_state(state_machine.get_node("PlatformDropState"), {"regrab_cooldown": 0.25})
		player.input.consume_jump()
		return

	# --- 退出方式 2：向上翻越 ---
	# 直接执行跳跃，利用 Godot 单向平台的物理特性，角色会自然穿透平台落到顶部站立
	if Input.is_action_just_pressed("jump"):
		# 这里使用基础跳跃力度，如果有需要可以写成 player.data.jump_force * 0.8
		player.velocity.y = -player.data.jump_force 
		state_machine.change_state(player.jump_state)
		player.input.consume_jump()
		return

func physics_update(_delta: float) -> void:
	var sensor = player.get_node("HeadSensor") as RayCast2D
	sensor.force_raycast_update() # 必须强制刷新，防止单帧延迟误判
	
	# --- 退出方式 3：移出边缘自然掉落 ---
	if not sensor.is_colliding() or not sensor.get_collider().is_in_group("hanging_platform"):
		player.velocity.x = 0
		# 因为是自然滑落不是主动下跳，直接切入普通下坠状态即可
		state_machine.change_state(player.fall_state)
		return

	# --- 悬挂左右移动 ---
	if not is_casting:
		var move_dir = player.input.move_direction
		player.velocity.x = move_dir * hang_climb_speed
		player.velocity.y = 0 
		
		if move_dir != 0:
			player.set_facing_direction(move_dir)
			player.animation.play("hang_move")
		else:
			player.animation.play("hang_idle")
	else:
		# 释放忍术时死锁位置
		player.velocity.x = 0
		player.velocity.y = 0

	player.move_and_slide()
