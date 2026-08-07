# res://scripts/enemy/boss/l3/states/Boss3JumpState.gd
## 跳跃状态：纯动画控制器，跳跃物理由 HandsComponent 统一处理
## 支持：起跳后自动接空中攻击 / 最高点释放火球 / 最高点空中投掷飞镖
extends Boss3State
class_name Boss3JumpState

## 是否已经起跳（由 HandsComponent 触发时即为 true）
var _has_jumped: bool = true
## 起跳后是否自动接空中攻击（AI 默认 true）
var _follow_with_air_attack: bool = true
## 是否在跳跃最高点释放火球
var _fireball_on_peak: bool = false
var _has_fired: bool = false
## 是否在跳跃最高点投掷飞镖（空中投掷，按血量规则选飞镖/火焰镖）
var _air_throw_on_peak: bool = false
var _has_thrown_dart: bool = false
## 是否已进入空中投掷动画（air_ninjutsu）
var _in_air_throw_anim: bool = false

const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fireball_ninjutsu.tscn")
const DART_SCENE = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
const FIRE_DART_SCENE = preload("res://scenes/enemy/l3/FireDart.tscn")

func enter(msg: Dictionary = {}) -> void:
	super()
	_follow_with_air_attack = msg.get("air_attack", true)
	_fireball_on_peak = msg.get("fireball", false)
	_air_throw_on_peak = msg.get("air_throw", false)
	_has_fired = false
	_has_thrown_dart = false
	_in_air_throw_anim = false
	_has_jumped = true
	_face_player()
	boss.animated_sprite.play("jump")
	AudioManager.play_sound(&"tiaoyue")

func update(_delta: float) -> void:
	if not _has_jumped:
		return

	# 空中投掷：走独立的 air_ninjutsu 动画流程，不接空中攻击
	if _air_throw_on_peak:
		_update_air_throw()
		return

	# 跳跃最高点：竖直速度从负变正时
	if _fireball_on_peak and not _has_fired and boss.velocity.y >= 0 and not boss.is_on_floor():
		_has_fired = true
		_fire_fireball_down()

	if boss.velocity.y > 0 and not boss.is_on_floor():
		if _follow_with_air_attack:
			state_machine.change_state_by_name("Boss3AirAttackState")
		else:
			state_machine.change_state_by_name("Boss3FallState")

## 空中投掷流程：最高点播放 air_ninjutsu → 第1帧投掷飞镖 → 动画播完下坠
func _update_air_throw() -> void:
	# 到达最高点（竖直速度从负变正）→ 播放空中投掷动画
	if not _in_air_throw_anim and boss.velocity.y >= 0 and not boss.is_on_floor():
		_in_air_throw_anim = true
		boss.velocity.y = 0.0
		boss.animated_sprite.play("air_ninjutsu")
		# 若同时设置了火球，最高点一并释放
		if _fireball_on_peak and not _has_fired:
			_has_fired = true
			_fire_fireball_down()

	# 动画第 1 帧投掷飞镖
	if _in_air_throw_anim and not _has_thrown_dart and boss.animated_sprite.frame >= 1:
		_has_thrown_dart = true
		_throw_dart_air()

	# 动画播完 → 下坠
	if _in_air_throw_anim and not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3FallState")

## 跳跃最高点向下释放火球
func _fire_fireball_down() -> void:
	if not boss or not is_instance_valid(boss):
		return
	var proj = FIREBALL_SCENE.instantiate() as BossFireballProjectile
	var base_pos = boss.global_position + Vector2(0, boss.data.ninjutsu_fireball_spawn_y)
	proj.set_direction(Vector2.DOWN)
	proj.global_position = base_pos
	get_tree().current_scene.add_child(proj)

## 跳跃最高点空中投掷飞镖（与地面投掷相同的血量规则）
## 血量 > 10：只投普通飞镖；血量 ≤ 10：火焰镖 50% / 普通飞镖 50%
func _throw_dart_air() -> void:
	if not boss or not is_instance_valid(boss) or not boss.player_ref:
		return

	var dir = (boss.player_ref.global_position - boss.global_position).normalized()
	var spawn_pos = boss.global_position + dir * 20.0 + Vector2(0, 0)

	var can_use_fire_dart = boss.current_hp <= 10 and randf() < 0.5
	if can_use_fire_dart:
		# 投掷火焰镖
		AudioManager.play_sound(boss.data.throw_fire_dart_sound)
		var dart = FIRE_DART_SCENE.instantiate()
		dart.initialize(dir, boss.data.throw_fire_dart_speed)
		dart.global_position = spawn_pos
		get_tree().current_scene.add_child(dart)
	else:
		# 投掷普通飞镖
		AudioManager.play_sound(boss.data.throw_dart_sound)
		var dart = DART_SCENE.instantiate()
		dart.global_position = spawn_pos
		get_tree().current_scene.add_child(dart)
		dart.initialize(dir, boss.data.throw_dart_speed)
