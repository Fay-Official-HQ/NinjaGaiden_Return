extends State

class_name HurtState

var hurt_timer: float = 0.0
const HURT_DURATION: float = 0.4
var knockback_speed: float = 180.0
var knockback_jump_force: float = 200.0

func enter(_msg: Dictionary = {}) -> void:
	player.animation.play("hurt")
	player.velocity.x = -player.facing_direction * knockback_speed
	player.velocity.y = -knockback_jump_force
	hurt_timer = HURT_DURATION

func update(delta: float) -> void:
	hurt_timer -= delta
	if hurt_timer <= 0:
		state_machine.change_state(_recover_state())

func physics_update(_delta: float) -> void:
	player.move_and_slide()

func exit() -> void:
	pass

func _recover_state() -> State:
	if player.is_on_floor():
		if player.input.move_direction != 0:
			return player.run_state
		else:
			return player.idle_state
	else:
		return player.fall_state
