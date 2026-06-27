extends BossState
class_name BossHurtState

var hurt_timer: float = 0.0
var _disabled_hitboxes: Array[Area2D] = []
var _flash_tween: Tween

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("hurt")
	boss.velocity = Vector2.ZERO
	hurt_timer = boss.data.hurt_duration

	_apply_knockback()
	_disable_all_hitboxes()
	_start_flash()

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_restore_all_hitboxes()
		_cleanup_flash()
		state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	_restore_all_hitboxes()
	_cleanup_flash()

func _apply_knockback() -> void:
	var knock_dir = -1.0 if boss.facing_direction > 0 else 1.0
	if not _has_ground_at(knock_dir):
		return
	boss.global_position.x += knock_dir * boss.data.knockback_distance

func _has_ground_at(dir: float) -> bool:
	var space_state = boss.get_world_2d().direct_space_state
	var target_x = boss.global_position.x + dir * boss.data.knockback_distance
	var from = Vector2(target_x, boss.global_position.y)
	var to = Vector2(target_x, boss.global_position.y + 48.0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _start_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	boss.animated_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	_flash_tween = create_tween()
	_flash_tween.tween_property(boss.animated_sprite, "modulate", Color.WHITE, boss.data.hurt_duration)

func _cleanup_flash() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	boss.animated_sprite.modulate = Color.WHITE

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
