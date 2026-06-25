extends BossState
class_name BossHurtState

var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.2

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("idle")
	boss.animated_sprite.modulate = Color(3.0, 3.0, 3.0, 1.0)
	hurt_timer = HURT_DURATION

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		boss.animated_sprite.modulate = Color.WHITE
		state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.move_and_slide()
