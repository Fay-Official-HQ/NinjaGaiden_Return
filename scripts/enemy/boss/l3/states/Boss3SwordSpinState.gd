# res://scripts/enemy/boss/l3/states/Boss3SwordSpinState.gd
## 剑术：旋转攻击（蓄力 → 地面突进旋转）
## 蓄力时长由 BossData_3.sword_charge_duration 数据驱动
extends Boss3State
class_name Boss3SwordSpinState

var _charging: bool = false
var _charge_timer: float = 0.0
var _spin_distance_left: float = 0.0
var _spinning: bool = false

func enter(_msg: Dictionary = {}) -> void:
	super()
	_face_player()
	# 蓄力阶段：播放 charge 姿势，到时后才真正旋转
	_charging = true
	_charge_timer = boss.data.sword_charge_duration
	boss.animated_sprite.play("charge")
	boss.velocity = Vector2.ZERO
	_spinning = false

func update(_delta: float) -> void:
	# 蓄力中：等待蓄力时长后开始旋转
	if _charging:
		_charge_timer -= _delta
		if _charge_timer <= 0.0:
			_start_spin()
		return
	if _spinning:
		# 撞墙提前结束旋转
		if boss.is_on_wall():
			_spinning = false
			boss.velocity.x = 0.0
			boss.sword_hit_box.set_deferred("monitoring", false)
			state_machine.change_state_by_name("Boss3IdleState")
			return
		_spin_distance_left -= abs(boss.velocity.x * _delta)
		if _spin_distance_left <= 0.0:
			_spinning = false
			boss.velocity.x = 0.0
			boss.sword_hit_box.set_deferred("monitoring", false)
	elif not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")

func _start_spin() -> void:
	_charging = false
	boss.animated_sprite.play("sword_spin")
	AudioManager.play_sound(&"jianxuanzhuan")
	boss.sword_hit_box.set_deferred("monitoring", true)
	_spin_distance_left = boss.data.sword_spin_distance
	_spinning = true
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * boss.data.sword_spin_speed_multiplier

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
