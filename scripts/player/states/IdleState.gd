# res://scripts/player/states/IdleState.gd
extends State

class_name IdleState

func enter(_msg: Dictionary = {}) -> void:
	player.animation.play("idle")

func physics_update(_delta: float) -> void:
	# 触发地面攻击（和原来一样，短按 J 瞬发）
	if Input.is_action_just_pressed("attack"):
		state_machine.change_state(state_machine.get_node("GroundAttackState"))
		return

	# 触发剑术备战 (急停进入架势)
	if Input.is_action_pressed("special_move"):
		state_machine.change_state(state_machine.get_node("SwordReadyState"))
		return

	# 触发地面忍术
	if Input.is_action_just_pressed("ninjutsu"):
		print("【调试】IdleState 检测到 ninjutsu 按键")
		state_machine.change_state(state_machine.get_node("GroundNinjutsuState"))
		return

	# 踩空坠落判定
	if not player.is_on_floor():
		state_machine.change_state(player.fall_state, {"imbalance": true})
		return

	# 【防误触兼容：极限帧同时按下方向键和跳跃键时下穿】
	if Input.is_action_pressed("nav_down") and Input.is_action_just_pressed("jump"):
		var can_drop = false
		for i in player.get_slide_collision_count():
			var collision = player.get_slide_collision(i)
			if collision:
				var collider = collision.get_collider()
				if collider and collider.is_in_group("hanging_platform"):
					can_drop = true
					break

		if can_drop:
			player.global_position.y += 2.0
			state_machine.change_state(player.fall_state, {"imbalance": false})
			player.input.consume_jump()
			return

	# 触发下蹲
	if Input.is_action_pressed("nav_down"):
		state_machine.change_state(state_machine.get_node("CrouchState"))
		return

	if player.input.consume_jump():
		state_machine.change_state(player.jump_state)
		return

	if player.input.move_direction != 0:
		state_machine.change_state(player.run_state)
		return

	player.movement.stop()
	player.move_and_slide()


