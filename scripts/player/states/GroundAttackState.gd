# res://scripts/player/states/GroundAttackState.gd
extends State

class_name GroundAttackState

var hit_box: PlayerHitBox
var attack_root: Node2D
var hit_enemies: Array[HurtBox] = []

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	player.animation.play("attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	hit_box = attack_root.get_node("HitBox") as PlayerHitBox
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = player.facing_direction


func update(_delta: float) -> void:
	var sprite = player.animation.sprite

	if hit_box and not hit_box.monitoring and sprite.animation == "attack" and sprite.frame >= 1:
		hit_box.set_deferred("monitoring", true)

	if hit_box and hit_box.monitoring:
		var areas = hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not hit_enemies.has(area):
				hit_enemies.append(area)
				area.take_damage(hit_box.damage)

	if sprite.animation == "attack" and not sprite.is_playing():
		_exit_attack()
		if player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)
		return

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
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = 1.0
