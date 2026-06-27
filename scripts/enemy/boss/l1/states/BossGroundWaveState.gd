extends BossState
class_name BossGroundWaveState

enum Phase { CHARGE, SPAWNING, FINISH }

var _phase: int = Phase.CHARGE
var _spawn_count: int = 0
var _spawn_timer: float = 0.0

const WAVE_COUNT: int = 3
const SPAWN_INTERVAL: float = 0.8
const GROUND_OFFSET_X: float = 25.0

var _ground_wave_scene: PackedScene = preload("res://scenes/enemy/boss/boss_ground_wave.tscn")

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("ground_wave")
	_phase = Phase.CHARGE
	_spawn_count = 0
	_spawn_timer = SPAWN_INTERVAL

func update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			if not boss.animated_sprite.is_playing():
				_phase = Phase.SPAWNING
				_spawn_timer = 0.0
		Phase.SPAWNING:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0 and _spawn_count < WAVE_COUNT:
				_spawn_wave()
				_spawn_count += 1
				_spawn_timer = SPAWN_INTERVAL
			if _spawn_count >= WAVE_COUNT:
				_phase = Phase.FINISH
				_spawn_timer = 0.3
		Phase.FINISH:
			_spawn_timer -= delta
			if _spawn_timer <= 0.0:
				state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.velocity.x = 0.0

func _spawn_wave() -> void:
	var wave = _ground_wave_scene.instantiate() as BossGroundWave
	var ground_pos = boss.get_ground_at(boss.global_position.x)
	var spawn_pos = Vector2(
		boss.global_position.x + boss.facing_direction * GROUND_OFFSET_X,
		ground_pos.y
	)
	wave.initialize(boss.facing_direction, spawn_pos)
	boss.get_parent().add_child(wave)

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)
