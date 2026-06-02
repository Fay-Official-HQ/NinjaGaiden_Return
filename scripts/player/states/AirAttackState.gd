# res://scripts/player/states/AirAttackState.gd
extends State

class_name AirAttackState

var is_imbalance: bool = false
var hit_box: PlayerHitBox
var attack_root: Node2D

func enter(msg: Dictionary = {}) -> void:
	is_imbalance = msg.get("imbalance", false)
	player.animation.play("air_attack")

	attack_root = player.get_node("AttackRoot") as Node2D
	hit_box = attack_root.get_node("HitBox") as PlayerHitBox
	if hit_box:
		hit_box.set_deferred("monitoring", true)
		attack_root.scale.x = player.facing_direction

func update(_delta: float) -> void:
	if player.is_on_floor():
		_exit_attack()
		state_machine.change_state(player.idle_state)
		return

	var sprite = player.animation.sprite
	if sprite.animation == "air_attack" and not sprite.is_playing():
		_exit_attack()
		state_machine.change_state(player.fall_state, {"imbalance": is_imbalance})
		return

	if hit_box and hit_box.monitoring:
		var areas = hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox:
				area.take_damage(hit_box.damage)

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
	if attack_root:
		attack_root.scale.x = 1.0
