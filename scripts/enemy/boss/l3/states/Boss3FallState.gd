# res://scripts/enemy/boss/l3/states/Boss3FallState.gd
extends Boss3State
class_name Boss3FallState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("fall")

func update(_delta: float) -> void:
	if boss.is_on_floor():
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(delta: float) -> void:
	# 空中无水平速度，仅受重力下落
	boss.velocity.x = 0.0
	_apply_gravity(delta)
	boss.move_and_slide()

func exit() -> void:
	super()
	boss.velocity.x = 0.0

func _apply_gravity(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
