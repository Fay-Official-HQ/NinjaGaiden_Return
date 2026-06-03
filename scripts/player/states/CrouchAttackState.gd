# res://scripts/player/states/CrouchAttackState.gd
extends State

class_name CrouchAttackState

var attack_root: Node2D
var crouch_hit_box: PlayerHitBox
var hit_enemies: Array[HurtBox] = []

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	player.animation.play("crouch_attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	crouch_hit_box = attack_root.get_node("CrouchHitBox") as PlayerHitBox
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	var sprite = player.animation.sprite

	if crouch_hit_box and not crouch_hit_box.monitoring and sprite.animation == "crouch_attack" and sprite.frame >= 1:
		crouch_hit_box.set_deferred("monitoring", true)

	if crouch_hit_box and crouch_hit_box.monitoring:
		var areas = crouch_hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not hit_enemies.has(area):
				hit_enemies.append(area)
				area.take_damage(crouch_hit_box.damage)

	if sprite.animation == "crouch_attack" and not sprite.is_playing():
		_exit_attack()
		if Input.is_action_pressed("nav_down"):
			state_machine.change_state(state_machine.get_node("CrouchState"))
		elif player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)

func physics_update(_delta: float) -> void:
		# 跳跃打断：攻击动画期间可按跳跃键取消并跳起
	if player.input.consume_jump():
		_exit_attack()
		state_machine.change_state(player.jump_state)
		return
	
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
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = 1.0
