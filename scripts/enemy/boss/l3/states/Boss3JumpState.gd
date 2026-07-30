# res://scripts/enemy/boss/l3/states/Boss3JumpState.gd
## 跳跃状态：纯动画控制器，跳跃物理由 HandsComponent 统一处理
extends Boss3State
class_name Boss3JumpState

## 是否已经起跳（由 HandsComponent 触发时即为 true）
var _has_jumped: bool = true
## 起跳后是否自动接空中攻击（AI 默认 true）
var _follow_with_air_attack: bool = true
## 是否在跳跃最高点释放火球
var _fireball_on_peak: bool = false
var _has_fired: bool = false

const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l3/ninjutsu/boss_fireball_ninjutsu.tscn")

func enter(msg: Dictionary = {}) -> void:
	super()
	_follow_with_air_attack = msg.get("air_attack", true)
	_fireball_on_peak = msg.get("fireball", false)
	_has_fired = false
	_has_jumped = true
	_face_player()
	boss.animated_sprite.play("jump")
	AudioManager.play_sound(&"tiaoyue")

func update(_delta: float) -> void:
	if not _has_jumped:
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

## 跳跃最高点向下释放火球
func _fire_fireball_down() -> void:
	if not boss or not is_instance_valid(boss):
		return
	var proj = FIREBALL_SCENE.instantiate() as BossFireballProjectile
	var base_pos = boss.global_position + Vector2(0, boss.data.ninjutsu_fireball_spawn_y)
	proj.set_direction(Vector2.DOWN)
	proj.global_position = base_pos
	get_tree().current_scene.add_child(proj)
