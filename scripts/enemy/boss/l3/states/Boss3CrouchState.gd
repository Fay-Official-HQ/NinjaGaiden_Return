# res://scripts/enemy/boss/l3/states/Boss3CrouchState.gd
extends Boss3State
class_name Boss3CrouchState

var _timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("crouch")
	_timer = boss.data.crouch_duration
	boss.set_hurtbox_crouch(true)

func exit() -> void:
	boss.set_hurtbox_crouch(false)

func update(_delta: float) -> void:
	_timer -= _delta
	if _timer <= 0.0:
		state_machine.change_state_by_name("Boss3CrouchAttackState")

func physics_update(delta: float) -> void:
	boss.velocity.x = 0.0
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()
