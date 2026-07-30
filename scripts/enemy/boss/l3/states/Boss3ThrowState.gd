# res://scripts/enemy/boss/l3/states/Boss3ThrowState.gd
## 投掷飞镖状态：向玩家方向随机投掷 FlyingNinjaDart 或 FireDart
## 仅在 RANGED 策略中由 BrainComponent 触发
extends Boss3State
class_name Boss3ThrowState

var _has_thrown: bool = false

const DART_SCENE = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn")
const FIRE_DART_SCENE = preload("res://scenes/enemy/l3/FireDart.tscn")

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("ground_ninjutsu")
	_has_thrown = false

func update(_delta: float) -> void:
	if not _has_thrown and boss.animated_sprite.frame >= 1:
		_has_thrown = true
		_throw_dart()
	if not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(_delta: float) -> void:
	boss.velocity.x = 0.0

## 随机选一个飞镖射向玩家
func _throw_dart() -> void:
	if not boss.player_ref:
		return

	var dir = (boss.player_ref.global_position - boss.global_position).normalized()
	var spawn_pos = boss.global_position + dir * 20.0 + Vector2(0, 0)

	if randi() % 2 == 0:
		# 投掷普通飞镖
		AudioManager.play_sound(boss.data.throw_dart_sound)
		var dart = DART_SCENE.instantiate()
		dart.global_position = spawn_pos
		get_tree().current_scene.add_child(dart)
		dart.initialize(dir, boss.data.throw_dart_speed)
	else:
		# 投掷爆炸飞镖
		AudioManager.play_sound(boss.data.throw_fire_dart_sound)
		var dart = FIRE_DART_SCENE.instantiate()
		dart.initialize(dir, boss.data.throw_fire_dart_speed)
		dart.global_position = spawn_pos
		get_tree().current_scene.add_child(dart)
