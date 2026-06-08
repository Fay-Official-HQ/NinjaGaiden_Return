extends State
class_name SwordDownslashState

# 下劈攻击框引用
var downslash_hit_box: Area2D
# 已命中的敌人列表（防止重复伤害）
var hit_enemies: Array[HurtBox] = []
# 进入后的短暂锁定时间（防按键抖动）
var _enter_lockout: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	_enter_lockout = 0.1

	# 先检查冷却,再消耗TP
	if player.sword.is_on_cooldown("downslash"):
		print("【下劈】冷却中,剩余:", player.sword.get_cooldown_remaining("downslash"), "秒")
		_fallback_to_neutral()
		return
	if not player.sword.consume_tp():
		print("【下劈】TP 不足")
		_fallback_to_neutral()
		return
	player.sword.start_cooldown("downslash")
	AudioManager.play_sound(&"hanjiao")
	AudioManager.play_sound(&"jianxiapi")
	print("【下劈】释放成功！剩余TP:", player.sword.current_tp, " 冷却5秒")

	player.animation.play("sword_downslash")

	# 轻微下压 + 常速重力(1.0x),保证动画播完再落地
	# 【调试】调大此值→下落更快,调小→更慢
	#player.velocity.y += 10.0

	hit_enemies.clear()
	downslash_hit_box = player.get_node("AttackRoot/SwordDownslashHitBox") as Area2D
	if downslash_hit_box:
		downslash_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	if _enter_lockout > 0:
		_enter_lockout -= _delta
	else:
		_check_buffer()

	# 落地立即结束
	if player.is_on_floor():
		_exit_hitbox()
		state_machine.change_state(player.idle_state)
		return

func physics_update(_delta: float) -> void:
	# 常速重力,限制最大下落速度
	# 【调试】调大 gravity* 后的系数→下落更快
	player.velocity.y += player.data.gravity * _delta
	# 【调试】调大 500→最高速更快,调小→更慢
	player.velocity.y = min(player.velocity.y, 500.0)

	# 缓慢水平移动(30%速度),可微调落点
	var move_dir = player.input.move_direction
	# 【调试】调大 0.3→水平移动更快
	player.velocity.x = move_dir * player.data.walk_speed * 0.3
	if move_dir != 0:
		player.set_facing_direction(move_dir)

	_poll_hitbox()
	player.move_and_slide()

func exit() -> void:
	_exit_hitbox()

func _fallback_to_neutral() -> void:
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
	else:
		state_machine.change_state(player.fall_state, {"imbalance": false})

func _exit_hitbox() -> void:
	if downslash_hit_box:
		downslash_hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()

func _poll_hitbox() -> void:
	if not downslash_hit_box or not downslash_hit_box.monitoring:
		return
	var areas = downslash_hit_box.get_overlapping_areas()
	for area in areas:
		if area is HurtBox and not hit_enemies.has(area):
			hit_enemies.append(area)
			area.take_damage(2)

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
