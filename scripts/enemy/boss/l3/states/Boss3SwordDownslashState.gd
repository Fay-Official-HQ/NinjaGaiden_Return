# res://scripts/enemy/boss/l3/states/Boss3SwordDownslashState.gd
## 剑术：下劈（朝玩家方向直线下劈，直到碰到地形（地板/墙壁）才结束）
## 注意：每帧 physics_update 强制重设速度，防止重力/帧序干扰
extends Boss3State
class_name Boss3SwordDownslashState

## 缓存的下劈方向（一次性锁定）
var _downslash_dir: Vector2

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("sword_downslash")
	AudioManager.play_sound(&"jianxiapi")
	boss.ignore_gravity = true

	# 面朝玩家
	if boss.player_ref:
		var dir = sign(boss.player_ref.global_position.x - boss.global_position.x)
		boss.set_facing_direction(dir)

	# 一次性锁定方向：朝玩家位置直线下劈
	# 防止垂直下落：水平差不足 40px 时强制偏移，确保斜角冲击
	if boss.player_ref:
		var target = boss.player_ref.global_position
		if abs(target.x - boss.global_position.x) < 40.0:
			target.x += 40.0 * boss.facing_direction
		_downslash_dir = (target - boss.global_position).normalized()
	else:
		_downslash_dir = Vector2(boss.facing_direction, 1).normalized()
	boss.velocity = _downslash_dir * boss.data.sword_downslash_speed

	# 持续开启攻击框，直到碰到地形才关闭
	boss.sword_hit_box.set_deferred("monitoring", true)

func physics_update(_delta: float) -> void:
	# 每帧强制锁定速度方向，防止重力/帧序覆盖
	boss.velocity = _downslash_dir * boss.data.sword_downslash_speed
	boss.ignore_gravity = true

	# 碰到地形（地板或墙壁）才结束下劈
	if boss.is_on_floor() or boss.is_on_wall():
		boss.velocity = Vector2.ZERO
		boss.sword_hit_box.set_deferred("monitoring", false)
		state_machine.change_state_by_name("Boss3IdleState")

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.ignore_gravity = false
	boss.velocity = Vector2.ZERO
