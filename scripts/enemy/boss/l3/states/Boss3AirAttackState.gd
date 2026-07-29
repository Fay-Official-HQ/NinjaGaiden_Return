# res://scripts/enemy/boss/l3/states/Boss3AirAttackState.gd
extends Boss3State
class_name Boss3AirAttackState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity.y = 0.0
	boss.animated_sprite.play("air_attack")
	# 空中攻击使用 SwordHitBox
	boss.sword_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	if not boss.animated_sprite.is_playing():
		boss.sword_hit_box.set_deferred("monitoring", false)
		state_machine.change_state_by_name("Boss3FallState")

func physics_update(delta: float) -> void:
	boss.velocity.x = 0.0
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
