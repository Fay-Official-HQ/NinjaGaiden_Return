# res://scripts/enemy/boss/l3/states/Boss3AttackState.gd
extends Boss3State
class_name Boss3AttackState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("attack")
	# 开启剑攻击框（EnemyHitBox 自动处理 area_entered 伤害）
	boss.sword_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	# 攻击动画播完 → 关闭攻击框 → 回待机
	if not boss.animated_sprite.is_playing():
		boss.sword_hit_box.set_deferred("monitoring", false)
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(delta: float) -> void:
	boss.velocity.x = 0.0
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
