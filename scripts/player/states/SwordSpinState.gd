extends State
class_name SwordSpinState

# 旋斩攻击框引用
var spin_hit_box: Area2D
# 已命中的敌人列表
var hit_enemies: Array[HurtBox] = []
# 进入后的短暂锁定时间
var _enter_lockout: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	_enter_lockout = 0.1

	if player.sword.is_on_cooldown("spin"):
		print("【旋斩】冷却中，剩余:", player.sword.get_cooldown_remaining("spin"), "秒")
		_fallback_to_neutral()
		return
	if not player.sword.consume_tp():
		print("【旋斩】TP 不足")
		_fallback_to_neutral()
		return
	player.sword.start_cooldown("spin")
	AudioManager.play_sound(&"hanjiao")
	AudioManager.play_sound(&"jianxuanzhuan") 
	print("【旋斩】释放成功！剩余TP:", player.sword.current_tp, "  冷却 5 秒")

	player.animation.play("sword_spin")
	player.set_hurtbox_crouch(true)

	# 向面朝方向短距离滑行（初速300，快速衰减）
	player.velocity.x = player.facing_direction * 300.0
	if not player.is_on_floor():
		player.velocity.y = 0.0

	hit_enemies.clear()
	spin_hit_box = player.get_node("AttackRoot/SwordSpinHitBox") as Area2D
	if spin_hit_box:
		spin_hit_box.set_deferred("monitoring", false)

	# 攻击框朝向跟随面朝方向
	var attack_root = player.get_node("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	if _enter_lockout > 0:
		_enter_lockout -= _delta
	else:
		_check_buffer()

	var sprite = player.animation.sprite
	if sprite.animation == "sword_spin":
		# 第1~3帧(frame 0~2)激活攻击框，之后关闭
		if sprite.frame <= 2 and spin_hit_box and not spin_hit_box.monitoring:
			spin_hit_box.set_deferred("monitoring", true)
		if sprite.frame > 2 and spin_hit_box and spin_hit_box.monitoring:
			spin_hit_box.set_deferred("monitoring", false)

		# 动画播完自动退出
		if not sprite.is_playing():
			_exit_hitbox()
			if player.is_on_floor():
				state_machine.change_state(player.idle_state)
			else:
				state_machine.change_state(player.fall_state, {"imbalance": false})

func physics_update(_delta: float) -> void:
	# 速度快速衰减到0（600/s），滑行距离很短
	player.velocity.x = move_toward(player.velocity.x, 0, 600 * _delta)

	# 空中使用时悬浮（锁定Y轴速度）
	if not player.is_on_floor():
		player.velocity.y = 0.0

	_poll_hitbox()
	player.move_and_slide()

func exit() -> void:
	_exit_hitbox()
	player.set_hurtbox_crouch(false)
	var attack_root = player.get_node("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = 1.0

func _fallback_to_neutral() -> void:
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
	else:
		state_machine.change_state(player.fall_state, {"imbalance": false})

func _exit_hitbox() -> void:
	if spin_hit_box:
		spin_hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()

func _poll_hitbox() -> void:
	if not spin_hit_box or not spin_hit_box.monitoring:
		return
	var areas = spin_hit_box.get_overlapping_areas()
	for area in areas:
		if area is HurtBox and not hit_enemies.has(area):
			hit_enemies.append(area)
			#造成2点伤害，直接写死
			area.take_heavy_damage(2)

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
