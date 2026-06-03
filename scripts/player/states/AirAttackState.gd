# res://scripts/player/states/AirAttackState.gd
extends State

class_name AirAttackState

var is_imbalance: bool = false
var hit_box: PlayerHitBox
var attack_root: Node2D
var hit_enemies: Array[HurtBox] = []

func enter(msg: Dictionary = {}) -> void:
	is_imbalance = msg.get("imbalance", false)
	player.animation.play("air_attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	hit_box = attack_root.get_node("HitBox") as PlayerHitBox
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = player.facing_direction

	# 立即激活攻击框（不再延迟到第二帧）
	if hit_box:
		hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	if player.is_on_floor():
		_exit_attack()
		state_machine.change_state(player.idle_state)
		return

	var sprite = player.animation.sprite

	# 手动检测重叠（攻击框已激活）
	if hit_box and hit_box.monitoring:
		var areas = hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not hit_enemies.has(area):
				hit_enemies.append(area)
				area.take_damage(hit_box.damage)

	if sprite.animation == "air_attack" and not sprite.is_playing():
		_exit_attack()
		state_machine.change_state(player.fall_state, {"imbalance": is_imbalance})

func physics_update(_delta: float) -> void:
	var move_dir = player.input.move_direction
	if move_dir != 0:
		if move_dir != player.facing_direction:
			is_imbalance = true
			player.velocity.x = move_dir * player.data.walk_speed * player.data.imbalance_speed_factor
		else:
			player.velocity.x = move_dir * player.data.walk_speed
	else:
		player.movement.stop()
	player.move_and_slide()

func exit() -> void:
	_exit_attack()

func _exit_attack() -> void:
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()
	if attack_root:
		attack_root.scale.x = 1.0
