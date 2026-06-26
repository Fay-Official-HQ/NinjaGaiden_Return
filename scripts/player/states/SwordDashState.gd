# res://scripts/player/states/SwordDashState.gd
extends State

class_name SwordDashState

# 突进速度倍率（你可以后期移到 PlayerData 里配置）
var dash_speed_multiplier: float = 2.5

# 剑术前冲专用全新攻击框
var dash_hit_box: SwordHitBox
var attack_root: Node2D
var hit_enemies: Array[HurtBox] = []

func enter(_msg: Dictionary = {}) -> void:
	if player.sword.is_on_cooldown("dash"):
		print("【突进】冷却中，剩余:", player.sword.get_cooldown_remaining("dash"), "秒")
		_fallback_to_neutral()
		return
	if not player.sword.consume_tp():
		print("【突进】TP 不足")
		_fallback_to_neutral()
		return
	player.sword.start_cooldown("dash")
	print("【突进】释放成功！剩余TP:", player.sword.current_tp, "  冷却 5 秒")

	player.animation.play("sword_dash")
	
	player.velocity.x = player.facing_direction * player.data.walk_speed * dash_speed_multiplier
	
	if not player.is_on_floor():
		player.velocity.y = 0.0

	attack_root = player.get_node("AttackRoot") as Node2D
	dash_hit_box = attack_root.get_node("SwordDashBox") as SwordHitBox
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	var sprite = player.animation.sprite

	# 第3帧（frame >= 2）才激活攻击框，造成伤害
	if dash_hit_box and not dash_hit_box.monitoring and sprite.animation == "sword_dash" and sprite.frame >= 2:
		dash_hit_box.set_deferred("monitoring", true)
		AudioManager.play_sound(&"jianqianchong")

	# 激活后持续检测命中
	if dash_hit_box and dash_hit_box.monitoring:
		var areas = dash_hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not hit_enemies.has(area):
				hit_enemies.append(area)
				area.take_heavy_damage(dash_hit_box.damage)

	# 动画播放完毕后，自动结束剑术动作
	if sprite.animation == "sword_dash" and not sprite.is_playing():
		_exit_dash()
		if player.is_on_floor():
			state_machine.change_state(player.idle_state)
		else:
			# 结束后在空中自然恢复下落
			state_machine.change_state(player.fall_state, {"imbalance": false})

func physics_update(_delta: float) -> void:
	# 持续维持突进极速，禁止玩家中途变向
	player.velocity.x = player.facing_direction * player.data.walk_speed * dash_speed_multiplier
	
	if not player.is_on_floor():
		player.velocity.y = 0.0 # 持续锁死重力
		
	player.move_and_slide()

func exit() -> void:
	_exit_dash()

func _fallback_to_neutral() -> void:
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
	else:
		state_machine.change_state(player.fall_state, {"imbalance": false})

func _exit_dash() -> void:
	if dash_hit_box:
		dash_hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = 1.0
