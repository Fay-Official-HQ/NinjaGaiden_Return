# res://scripts/player/states/CrouchState.gd
extends State

class_name CrouchState

func enter(_msg: Dictionary = {}) -> void:
	player.animation.play("crouch") 
	player.velocity.x = 0
	player.set_hurtbox_crouch(true)

func exit() -> void:
	player.set_hurtbox_crouch(false)

func physics_update(_delta: float) -> void:
	# 1. 如果松开下方向键，站起来恢复待机状态
	if not Input.is_action_pressed("nav_down"):
		state_machine.change_state(player.idle_state)
		return

	# 2. 下蹲时发动下蹲攻击（和原来一样，短按 J 瞬发）
	if Input.is_action_just_pressed("attack"):
		state_machine.change_state(state_machine.get_node("CrouchAttackState"))
		return

	# 3. 下蹲时释放忍术
	if Input.is_action_just_pressed("ninjutsu"):
		state_machine.change_state(state_machine.get_node("GroundNinjutsuState"))
		return

	# 4. 【下穿触发】：下蹲时按下跳跃键
	if Input.is_action_just_pressed("jump"):
		# 进行不发生实际位移的虚拟碰撞射线探测
		var test_collision = player.move_and_collide(Vector2(0, 2), true)
		if test_collision:
			var collider = test_collision.get_collider()
			# 如果脚踩的是单向吊台，果断切入专属的“下蹲穿透状态”
			if collider and collider.is_in_group("hanging_platform"):
				state_machine.change_state(state_machine.get_node("PlatformDropState"))
				player.input.consume_jump()
				return
		
		# 如果脚下不是吊台而是普通实心平地，允许正常向上原地跳跃
		state_machine.change_state(player.jump_state)
		player.input.consume_jump()
		return

	player.move_and_slide()
