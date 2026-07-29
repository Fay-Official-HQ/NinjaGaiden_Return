# res://scripts/enemy/boss/l3/states/Boss3JumpState.gd
extends Boss3State
class_name Boss3JumpState

## 是否已经起跳
var _has_jumped: bool = false
## 起跳后是否自动接空中攻击（AI 默认 true）
var _follow_with_air_attack: bool = true

func enter(msg: Dictionary = {}) -> void:
	super()
	_follow_with_air_attack = msg.get("air_attack", true)
	_has_jumped = false
	boss.animated_sprite.play("jump")

func update(_delta: float) -> void:
	if _has_jumped and boss.velocity.y > 0 and not boss.is_on_floor():
		if _follow_with_air_attack:
			state_machine.change_state_by_name("Boss3AirAttackState")
		else:
			state_machine.change_state_by_name("Boss3FallState")

func physics_update(delta: float) -> void:
	if not _has_jumped:
		boss.velocity.y = boss.data.jump_velocity
		_has_jumped = true
	# 空中无水平速度
	boss.velocity.x = 0.0
	_face_player()
	_apply_gravity(delta)
	boss.move_and_slide()

func exit() -> void:
	super()
	boss.velocity.x = 0.0

func _apply_gravity(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
