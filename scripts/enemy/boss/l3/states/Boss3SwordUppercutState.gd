# res://scripts/enemy/boss/l3/states/Boss3SwordUppercutState.gd
## 剑术：上挑（蓄力 → 地面突进上挑，到最高点后下坠）
## 蓄力时长由 BossData_3.sword_charge_duration 数据驱动
extends Boss3State
class_name Boss3SwordUppercutState

var _charging: bool = false
var _charge_timer: float = 0.0
var _in_attack: bool = false
var _dash_distance_left: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	_face_player()
	# 蓄力阶段：播放 charge 姿势，到时后才真正上挑
	_charging = true
	_charge_timer = boss.data.sword_charge_duration
	boss.animated_sprite.play("charge")
	boss.velocity = Vector2.ZERO
	_in_attack = false

func update(delta: float) -> void:
	# 蓄力中：等待蓄力时长后开始上挑
	if _charging:
		_charge_timer -= delta
		if _charge_timer <= 0.0:
			_start_uppercut()
		return

func _start_uppercut() -> void:
	_charging = false
	boss.animated_sprite.play("sword_uppercut")
	AudioManager.play_sound(&"jianshangtiao")
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.velocity.y = boss.data.jump_velocity * boss.data.uppercut_jump_multiplier
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * boss.data.uppercut_speed_multiplier
	_dash_distance_left = boss.data.uppercut_dash_distance
	_in_attack = true

func physics_update(delta: float) -> void:
	# 蓄力期间不执行攻击逻辑
	if _charging:
		boss.velocity = Vector2.ZERO
		return
	# 撞墙提前结束前突
	if _in_attack and boss.is_on_wall():
		boss.velocity.x = 0.0
		_dash_distance_left = 0.0

	# 前突进距离耗尽 → 清空水平速度
	if _in_attack and _dash_distance_left > 0.0:
		_dash_distance_left -= abs(boss.velocity.x * delta)
		if _dash_distance_left <= 0.0:
			boss.velocity.x = 0.0

	# 升到最高点 → 结束攻击，进入下落状态
	if _in_attack and boss.velocity.y > 0:
		_in_attack = false
		boss.sword_hit_box.set_deferred("monitoring", false)
		boss.velocity.x = 0.0
		state_machine.change_state_by_name("Boss3FallState")

	# 下坠后落地
	if not _in_attack and boss.is_on_floor():
		state_machine.change_state_by_name("Boss3IdleState")

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
