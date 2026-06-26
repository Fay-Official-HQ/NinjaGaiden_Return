extends BossState
class_name BossHurtState

const HURT_DURATION: float = 1.5
const KNOCKBACK_DISTANCE: float = 10.0

var hurt_timer: float = 0.0
var _disabled_hitboxes: Array[Area2D] = []

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("hurt")
	boss.velocity = Vector2.ZERO
	hurt_timer = HURT_DURATION

	_apply_knockback()
	_disable_all_hitboxes()

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		_restore_all_hitboxes()
		state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.move_and_slide()

func exit() -> void:
	_restore_all_hitboxes()

func _apply_knockback() -> void:
	var knock_dir = -1.0 if boss.facing_direction > 0 else 1.0
	boss.global_position.x += knock_dir * KNOCKBACK_DISTANCE

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
