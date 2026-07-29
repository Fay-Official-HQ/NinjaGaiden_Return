# res://scripts/enemy/boss/l3/states/Boss3GroundNinjutsuState.gd
## 地面忍术状态：播放 ground_ninjutsu，第 1 帧随机释放一个忍术
extends Boss3State
class_name Boss3GroundNinjutsuState

var _has_cast: bool = false

const FIRE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fire_ninjutsu.tscn")
const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fireball_ninjutsu.tscn")
const BOOMERANG_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_boomerang_ninjutsu.tscn")
const EDGE_BLADE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_edge_blade_ninjutsu.tscn")

var _ninjutsu_types: Array[int] = [0, 1, 2, 3]

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("ground_ninjutsu")
	_has_cast = false

func update(_delta: float) -> void:
	var sprite = boss.animated_sprite
	if not _has_cast and sprite.animation == "ground_ninjutsu" and sprite.frame >= 1:
		_has_cast = true
		_cast_random_ninjutsu()
	if sprite.animation == "ground_ninjutsu" and not sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func exit() -> void:
	_has_cast = false
	boss.velocity.x = 0.0

func _cast_random_ninjutsu() -> void:
	var chosen = _ninjutsu_types[randi() % _ninjutsu_types.size()]
	match chosen:
		0:
			_cast_fire()
		1:
			_cast_fireball()
		2:
			_cast_boomerang()
		3:
			_cast_edgeblade()

func _cast_fire() -> void:
	AudioManager.play_sound(&"renshuhuoyan")
	var dir = 1.0 if boss.facing_direction > 0 else -1.0
	var base_pos = boss.global_position + Vector2(dir * boss.data.ninjutsu_spawn_offset_x, boss.data.ninjutsu_fire_spawn_y)
	var base_angle = Vector2(dir, -1).normalized()
	var offsets = [-15.0, 0.0, 15.0]
	for offset in offsets:
		var proj = FIRE_SCENE.instantiate() as BossFireProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_fireball() -> void:
	AudioManager.play_sound(&"renshuhuoqiu")
	var dir = 1.0 if boss.facing_direction > 0 else -1.0
	var base_pos = boss.global_position + Vector2(dir * boss.data.ninjutsu_spawn_offset_x, boss.data.ninjutsu_fireball_spawn_y)
	var base_angle = Vector2(dir, 1).normalized()
	var offsets = [-15.0, 0.0, 15.0]
	for offset in offsets:
		var proj = FIREBALL_SCENE.instantiate() as BossFireballProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_boomerang() -> void:
	AudioManager.play_sound(&"renshubiao")
	var proj = BOOMERANG_SCENE.instantiate() as BossBoomerang
	var dir = Vector2(boss.facing_direction, 0)
	proj.initialize(boss, dir)
	get_tree().current_scene.add_child(proj)

func _cast_edgeblade() -> void:
	AudioManager.play_sound(&"renshulengren")
	for d in [Vector2.UP, Vector2.DOWN]:
		var proj = EDGE_BLADE_SCENE.instantiate() as BossEdgeBlade
		proj.initialize(boss, d)
		get_tree().current_scene.add_child(proj)
