extends BossState
class_name BossHurtState

var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.3

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("hurt")
	boss.velocity = Vector2.ZERO
	hurt_timer = HURT_DURATION

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0.0:
		state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.move_and_slide()
