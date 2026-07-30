# res://scripts/enemy/boss/l3/states/Boss3AirNinjutsuState.gd
## 空中忍术状态：起跳 → 最高点播放 air_ninjutsu → 第 1 帧随机释放忍术 → 下坠
extends Boss3State
class_name Boss3AirNinjutsuState

var _has_jumped: bool = false
var _has_cast: bool = false
var _in_anim: bool = false
var _ninjutsu_type: int = -1  # 由 HandsComponent 通过 msg 传入

const FIRE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fire_ninjutsu.tscn")
const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fireball_ninjutsu.tscn")
const BOOMERANG_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_boomerang_ninjutsu.tscn")
const EDGE_BLADE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_edge_blade_ninjutsu.tscn")

func enter(msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("jump")
	_has_jumped = false
	_has_cast = false
	_in_anim = false
	_ninjutsu_type = msg.get("ninjutsu_type", -1)

func update(_delta: float) -> void:
	# 起跳后到达最高点 → 播放空中忍术动画
	if _has_jumped and not _in_anim and boss.velocity.y > 0:
		_in_anim = true
		boss.velocity.y = 0.0
		boss.animated_sprite.play("air_ninjutsu")

	# 动画第 1 帧释放忍术
	if _in_anim and not _has_cast and boss.animated_sprite.frame >= 1:
		_has_cast = true
		_cast_ninjutsu_by_type(_ninjutsu_type)

	# 动画播完 → 下坠
	if _in_anim and not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3FallState")

func physics_update(_delta: float) -> void:
	if not _has_jumped:
		boss.velocity.y = boss.data.jump_velocity
		_has_jumped = true
	boss.velocity.x = 0.0
	_face_player()

func exit() -> void:
	_has_cast = false
	_in_anim = false
	boss.velocity.x = 0.0

## 根据传入类型释放忍术，-1 时随机选择
func _cast_ninjutsu_by_type(type_index: int) -> void:
	var chosen = type_index
	if chosen < 0 or chosen > 3:
		var types: Array[int] = [0, 1, 2, 3]
		chosen = types[randi() % types.size()]
	match chosen:
		0: _cast_fire()
		1: _cast_fireball()
		2: _cast_boomerang()
		3: _cast_edgeblade()

func _cast_fire() -> void:
	AudioManager.play_sound(&"jianqianchong")
	var dir = 1.0 if boss.facing_direction > 0 else -1.0
	var base_pos = boss.global_position + Vector2(dir * boss.data.ninjutsu_spawn_offset_x, boss.data.ninjutsu_fire_spawn_y)
	var base_angle = Vector2(dir, -1).normalized()
	for offset in [-15.0, 0.0, 15.0]:
		var proj = FIRE_SCENE.instantiate() as BossFireProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_fireball() -> void:
	AudioManager.play_sound(&"shibingfashe")
	var dir = 1.0 if boss.facing_direction > 0 else -1.0
	var base_pos = boss.global_position + Vector2(dir * boss.data.ninjutsu_spawn_offset_x, boss.data.ninjutsu_fireball_spawn_y)
	var base_angle = Vector2(dir, 1).normalized()
	for offset in [-15.0, 0.0, 15.0]:
		var proj = FIREBALL_SCENE.instantiate() as BossFireballProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_boomerang() -> void:
	AudioManager.play_sound(&"jianxuanzhuan")
	var proj = BOOMERANG_SCENE.instantiate() as BossBoomerang
	proj.initialize(boss, Vector2(boss.facing_direction, 0))
	get_tree().current_scene.add_child(proj)

func _cast_edgeblade() -> void:
	AudioManager.play_sound(&"fangyu")
	for d in [Vector2.UP, Vector2.DOWN]:
		var proj = EDGE_BLADE_SCENE.instantiate() as BossEdgeBlade
		proj.initialize(boss, d)
		get_tree().current_scene.add_child(proj)
