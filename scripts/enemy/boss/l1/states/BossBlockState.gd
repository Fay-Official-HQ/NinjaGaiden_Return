extends BossState
class_name BossBlockState

const MAX_BLOCK_TIME: float = 3.0
var _block_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_block_timer = MAX_BLOCK_TIME
	_face_player()

func update(delta: float) -> void:
	if not boss.player_ref:
		state_machine.change_state_by_name("BossIdleState")
		return
	boss.animated_sprite.play("block")
	_face_player()
	_block_timer -= delta
	if _block_timer <= 0.0:
		state_machine.change_state_by_name("BossIdleState")
		return
	var dist_x = abs(boss.player_ref.global_position.x - boss.global_position.x)
	if dist_x > 130.0:
		state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.velocity = Vector2.ZERO

func _face_player() -> void:
	var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(dir)
