# res://scripts/enemy/boss/l3/states/Boss3CrouchAttackState.gd
extends Boss3State
class_name Boss3CrouchAttackState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("crouch_attack")
	AudioManager.play_sound(&"gongji")
	boss.set_hurtbox_crouch(true)
	# 开启下蹲攻击框（TempHitBox 默认关闭，此处手动开启）
	boss.crouch_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	# 动画播完 → 关闭攻击框 → 回待机
	if not boss.animated_sprite.is_playing():
		boss.crouch_hit_box.set_deferred("monitoring", false)
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(_delta: float) -> void:
	boss.velocity.x = 0.0

func exit() -> void:
	boss.crouch_hit_box.set_deferred("monitoring", false)
	boss.set_hurtbox_crouch(false)
	boss.velocity.x = 0.0
