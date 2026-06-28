extends BossState
class_name BossWalkState

var _walk_timer: float = 0.0

const WALK_DURATION_MIN: float = 1.0
const WALK_DURATION_MAX: float = 3.0

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("walk")
	_walk_timer = randf_range(WALK_DURATION_MIN, WALK_DURATION_MAX)

func update(delta: float) -> void:
	if not boss.player_ref:
		state_machine.change_state_by_name("BossIdleState")
		return
	_walk_timer -= delta
	if _walk_timer <= 0.0:
		state_machine.change_state_by_name("BossIdleState")
	_face_player()

func physics_update(_delta: float) -> void:
	if boss.player_ref:
		boss.velocity.x = boss.facing_direction * boss.data.move_speed

func _face_player() -> void:
	var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(dir)
