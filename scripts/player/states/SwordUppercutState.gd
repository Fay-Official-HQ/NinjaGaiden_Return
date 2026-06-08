extends State
class_name SwordUppercutState

# 上挑攻击框引用
var uppercut_hit_box: Area2D
# 已命中的敌人列表（防止重复伤害）
var hit_enemies: Array[HurtBox] = []
# 进入后的短暂锁定时间（防止按键抖动）
var _enter_lockout: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	_enter_lockout = 0.1

	# 先检查冷却，再消耗 TP，最后开始冷却
	if player.sword.is_on_cooldown("uppercut"):
		print("【上挑】冷却中，剩余:", player.sword.get_cooldown_remaining("uppercut"), "秒")
		_fallback_to_neutral()
		return
	if not player.sword.consume_tp():
		print("【上挑】TP 不足")
		_fallback_to_neutral()
		return
	player.sword.start_cooldown("uppercut")
	AudioManager.play_sound(&"hanjiao")
	AudioManager.play_sound(&"jianshangtiao")
	print("【上挑】释放成功！剩余TP:", player.sword.current_tp, "  冷却 5 秒")

	player.animation.play("sword_uppercut")
	# 向上跃起（跳跃力的 1.2 倍）
	player.velocity.y = -player.data.jump_force * 1.2

	hit_enemies.clear()
	uppercut_hit_box = player.get_node("AttackRoot/SwordUppercutHitBox") as Area2D
	if uppercut_hit_box:
		uppercut_hit_box.set_deferred("monitoring", false)

func update(_delta: float) -> void:
	if _enter_lockout > 0:
		_enter_lockout -= _delta
	else:
		_check_buffer()

	var sprite = player.animation.sprite
	if sprite.animation == "sword_uppercut":
		# 第2帧(frame=1)开始激活攻击框
		if sprite.frame >= 1 and uppercut_hit_box and not uppercut_hit_box.monitoring:
			uppercut_hit_box.set_deferred("monitoring", true)

		# 动画播完 → 清理攻击框并退出
		if not sprite.is_playing():
			_exit_hitbox()
			if player.is_on_floor():
				state_machine.change_state(player.idle_state)
			else:
				state_machine.change_state(player.fall_state, {"imbalance": false})

func physics_update(_delta: float) -> void:
	# 空中可水平移动
	var move_dir = player.input.move_direction
	if move_dir != 0:
		player.velocity.x = move_dir * player.data.walk_speed
		player.set_facing_direction(move_dir)
	else:
		player.movement.stop()

	_poll_hitbox()
	player.move_and_slide()

func exit() -> void:
	_exit_hitbox()

# 关闭攻击框 + 清空命中列表
func _fallback_to_neutral() -> void:
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
	else:
		state_machine.change_state(player.fall_state, {"imbalance": false})

func _exit_hitbox() -> void:
	if uppercut_hit_box:
		uppercut_hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()

func _poll_hitbox() -> void:
	if not uppercut_hit_box or not uppercut_hit_box.monitoring:
		return
	var areas = uppercut_hit_box.get_overlapping_areas()
	for area in areas:
		if area is HurtBox and not hit_enemies.has(area):
			hit_enemies.append(area)
			area.take_damage(2)

# 无缝衔接检测：技能期间按下 L+方向 则缓存输入，动画结束后自动连招
func _check_buffer() -> void:
	if not Input.is_action_just_pressed("special_move"):
		return
	if player.input.up_pressed:
		player.sword.buffer_input("uppercut")
		print("【剑术缓冲】缓存: uppercut")
	elif player.input.down_pressed:
		player.sword.buffer_input("downslash")
		print("【剑术缓冲】缓存: downslash")
	else:
		var dir = player.input.move_direction
		if dir == player.facing_direction:
			player.sword.buffer_input("dash")
			print("【剑术缓冲】缓存: dash")
		elif dir == -player.facing_direction:
			player.sword.buffer_input("spin")
			print("【剑术缓冲】缓存: spin")
