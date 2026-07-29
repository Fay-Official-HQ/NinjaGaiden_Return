# res://scripts/enemy/boss/l3/states/Boss3SwordDownslashState.gd
## 剑术：下劈（空中发动，受重力下坠，落地结束）
extends Boss3State
class_name Boss3SwordDownslashState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("sword_downslash")
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	if not boss.animated_sprite.is_playing():
		boss.sword_hit_box.set_deferred("monitoring", false)

func physics_update(delta: float) -> void:
	boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()
	if boss.is_on_floor():
		state_machine.change_state_by_name("Boss3IdleState")

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
