# res://scripts/player/states/CrouchAttackState.gd
extends State

class_name CrouchAttackState

var attack_root: Node2D
var crouch_hit_box: PlayerHitBox

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	player.animation.play("crouch_attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	crouch_hit_box = attack_root.get_node("CrouchHitBox") as PlayerHitBox
	
	if crouch_hit_box:
		crouch_hit_box.set_deferred("monitoring", true)
		# 根据玩家朝向翻转攻击根节点
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	# 动画播放完毕结算
	var sprite = player.animation.sprite
	if sprite.animation == "crouch_attack" and not sprite.is_playing():
		_exit_attack()
		# 根据按键状态决定恢复状态
		if Input.is_action_pressed("nav_down"):
			state_machine.change_state(state_machine.get_node("CrouchState"))
		elif player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)
		return

	# 手动检测重叠，对敌人造成伤害
	if crouch_hit_box and crouch_hit_box.monitoring:
		var areas = crouch_hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox:
				area.take_damage(crouch_hit_box.damage)

func physics_update(_delta: float) -> void:
	player.movement.stop()
	if not player.is_on_floor():
		_exit_attack()
		state_machine.change_state(player.fall_state, {"imbalance": true})
		return
	player.move_and_slide()

func exit() -> void:
	_exit_attack()

func _exit_attack() -> void:
	if crouch_hit_box:
		crouch_hit_box.set_deferred("monitoring", false)
	if attack_root:
		attack_root.scale.x = 1.0
