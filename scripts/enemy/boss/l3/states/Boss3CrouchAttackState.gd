# res://scripts/enemy/boss/l3/states/Boss3CrouchAttackState.gd
extends Boss3State
class_name Boss3CrouchAttackState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("crouch_attack")
	boss.set_hurtbox_crouch(true)
	# 开启下蹲攻击框（TempHitBox 默认关闭，此处手动开启）
	boss.crouch_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	# 动画播完 → 关闭攻击框 → 回待机
	if not boss.animated_sprite.is_playing():
		boss.crouch_hit_box.set_deferred("monitoring", false)
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(delta: float) -> void:
	boss.velocity.x = 0.0
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func exit() -> void:
	boss.crouch_hit_box.set_deferred("monitoring", false)
	boss.set_hurtbox_crouch(false)
	boss.velocity.x = 0.0
