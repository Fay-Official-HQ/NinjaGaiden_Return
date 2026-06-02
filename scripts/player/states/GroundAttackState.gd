# res://scripts/player/states/GroundAttackState.gd
extends State

class_name GroundAttackState

var hit_box: PlayerHitBox
var attack_root: Node2D

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	player.animation.play("attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	hit_box = attack_root.get_node("HitBox") as PlayerHitBox
	if hit_box:
		hit_box.set_deferred("monitoring", true)
		# 翻转整个攻击根节点，实现以玩家为中心的左右镜像
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	var sprite = player.animation.sprite
	if sprite.animation == "attack" and not sprite.is_playing():
		_exit_attack()
		if player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)
		return

	# 手动检测重叠
	if hit_box and hit_box.monitoring:
		var areas = hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox:
				area.take_damage(hit_box.damage)

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
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	# 重置缩放，避免影响其他逻辑
	if attack_root:
		attack_root.scale.x = 1.0
