extends BossState
class_name BossHurtState_2

var hurt_timer: float = 0.0
var _disabled_hitboxes: Array[Area2D] = []

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("hurt")
	boss.velocity = Vector2.ZERO
	# 受伤闪白
	boss._flash_white()
	# 受伤时禁用摄像机锚定，让击退效果可见
	boss._anchor_enabled = false
	hurt_timer = boss.data.hurt_duration
	_apply_knockback()
	_disable_all_hitboxes()

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_restore_all_hitboxes()
		# 先恢复锚定再切回飞行，避免下一帧位置跳跃
		boss._anchor_enabled = true
		state_machine.change_state_by_name("BossFlyState")

func physics_update(_delta: float) -> void:
	boss.velocity.x = move_toward(boss.velocity.x, 0.0, 200.0 * _delta)

func exit() -> void:
	_restore_all_hitboxes()
	boss._anchor_enabled = true

func _apply_knockback() -> void:
	var knock_dir = -1.0 if boss.facing_direction > 0 else 1.0
	boss.global_position.x += knock_dir * boss.data.knockback_distance

func _disable_all_hitboxes() -> void:
	_disabled_hitboxes.clear()
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if not attack_root:
		return
	for child in attack_root.get_children():
		if child is Area2D:
			_disabled_hitboxes.append(child)
			child.set_deferred("monitoring", false)

func _restore_all_hitboxes() -> void:
	for hitbox in _disabled_hitboxes:
		if is_instance_valid(hitbox):
			hitbox.set_deferred("monitoring", true)
	_disabled_hitboxes.clear()
