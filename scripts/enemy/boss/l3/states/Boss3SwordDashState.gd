# res://scripts/enemy/boss/l3/states/Boss3SwordDashState.gd
## 剑术：前冲（直接冲刺 → 恢复）
extends Boss3State
class_name Boss3SwordDashState

var _dash_timer: float = 0.0
var _in_dash: bool = false
var _recover_timer: float = 0.0

func enter(_msg: Dictionary = {}) -> void:
	super()
	_face_player()
	boss.animated_sprite.play("sword_dash")
	AudioManager.play_sound(&"jianqianchong")
	boss.velocity.x = boss.facing_direction * boss.data.sword_dash_speed
	var dash_time = boss.data.sword_dash_distance / max(boss.data.sword_dash_speed, 1.0)
	_dash_timer = dash_time
	_in_dash = true
	_recover_timer = 0.0
	boss.sword_hit_box.set_deferred("monitoring", true)

func update(delta: float) -> void:
	if _in_dash:
		# 撞墙提前结束冲刺
		if boss.is_on_wall():
			_in_dash = false
			boss.velocity.x = 0.0
			boss.sword_hit_box.set_deferred("monitoring", false)
			_recover_timer = boss.data.sword_dash_recover_duration
			return
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_in_dash = false
			boss.velocity.x = 0.0
			boss.sword_hit_box.set_deferred("monitoring", false)
			_recover_timer = boss.data.sword_dash_recover_duration
	elif _recover_timer > 0.0:
		_recover_timer -= delta
		if _recover_timer <= 0.0:
			state_machine.change_state_by_name("Boss3IdleState")

func physics_update(_delta: float) -> void:
	pass

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
