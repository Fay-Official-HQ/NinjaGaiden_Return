# res://scripts/enemy/boss/l3/states/Boss3GroundNinjutsuState.gd
## 地面忍术状态：播放 ground_ninjutsu，第 1 帧随机释放一个忍术
extends Boss3State
class_name Boss3GroundNinjutsuState

var _has_cast: bool = false
var _ninjutsu_type: int = -1  # 由 HandsComponent 通过 msg 传入

const FIRE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fire_ninjutsu.tscn")
const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fireball_ninjutsu.tscn")
const BOOMERANG_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_boomerang_ninjutsu.tscn")
const EDGE_BLADE_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_edge_blade_ninjutsu.tscn")

func enter(msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("ground_ninjutsu")
	_has_cast = false
	# 从 msg 读取指定忍术类型，-1 或无效时随机
	_ninjutsu_type = msg.get("ninjutsu_type", -1)

func update(_delta: float) -> void:
	var sprite = boss.animated_sprite
	if not _has_cast and sprite.animation == "ground_ninjutsu" and sprite.frame >= 1:
		_has_cast = true
		_cast_ninjutsu_by_type(_ninjutsu_type)
	if sprite.animation == "ground_ninjutsu" and not sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(_delta: float) -> void:
	# 由 HandsComponent 统一处理重力
	pass

func exit() -> void:
	_has_cast = false
	boss.velocity.x = 0.0

## 根据传入类型释放忍术，-1 时随机选择
func _cast_ninjutsu_by_type(type_index: int) -> void:
	var chosen = type_index
	if chosen < 0 or chosen > 3:
		var types: Array[int] = [0, 1, 2, 3]
		chosen = types[randi() % types.size()]
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
	AudioManager.play_sound(&"jianqianchong")
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
	AudioManager.play_sound(&"shibingfashe")
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
	AudioManager.play_sound(&"jianxuanzhuan")
	var proj = BOOMERANG_SCENE.instantiate() as BossBoomerang
	var dir = Vector2(boss.facing_direction, 0)
	proj.initialize(boss, dir)
	get_tree().current_scene.add_child(proj)

func _cast_edgeblade() -> void:
	AudioManager.play_sound(&"fangyu")
	for d in [Vector2.UP, Vector2.DOWN]:
		var proj = EDGE_BLADE_SCENE.instantiate() as BossEdgeBlade
		proj.initialize(boss, d)
		get_tree().current_scene.add_child(proj)
