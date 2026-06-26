extends BossState
class_name BossJumpState

enum Phase { CHARGE, JUMP, LAND }

var _phase: int = Phase.CHARGE
var _charge_timer: float = 0.0
var _land_timer: float = 0.0
var _start_pos: Vector2
var _target_pos: Vector2
var _jump_progress: float = 0.0
var _jump_dir: float = 1.0

const CHARGE_DURATION: float = 0.7
const LAND_DURATION: float = 0.7
const JUMP_DURATION: float = 0.6
const ARC_HEIGHT: float = 90.0

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_face_player()
	if not _resolve_target():
		state_machine.change_state_by_name("BossIdleState")
		return
	boss.animated_sprite.play("crouch")
	_phase = Phase.CHARGE
	_charge_timer = CHARGE_DURATION

func update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_start_jump()
		Phase.LAND:
			_land_timer -= delta
			if _land_timer <= 0.0:
				state_machine.change_state_by_name("BossIdleState")

func physics_update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			boss.velocity.x = 0.0
		Phase.JUMP:
			_jump_progress += delta / JUMP_DURATION
			if _jump_progress >= 1.0:
				boss.global_position = _target_pos
				_start_land()
				return
			var px = lerp(_start_pos.x, _target_pos.x, _jump_progress)
			var py = _start_pos.y - ARC_HEIGHT * sin(_jump_progress * PI)
			var desired = Vector2(px, py)
			boss.velocity = (desired - boss.global_position) / delta
		Phase.LAND:
			boss.velocity.x = 0.0

func _resolve_target() -> bool:
	if not boss.player_ref:
		return false
	_target_pos = boss.get_ground_at(boss.player_ref.global_position.x)
	_jump_dir = 1.0 if _target_pos.x > boss.global_position.x else -1.0
	return true

func _start_jump() -> void:
	_start_pos = boss.global_position
	_phase = Phase.JUMP
	_jump_progress = 0.0
	boss.animated_sprite.play("jump")
	boss.set_facing_direction(_jump_dir)

func _start_land() -> void:
	_phase = Phase.LAND
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("crouch")
	_land_timer = LAND_DURATION

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)

func exit() -> void:
	_phase = Phase.CHARGE
