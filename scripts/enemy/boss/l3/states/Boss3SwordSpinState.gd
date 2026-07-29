# res://scripts/enemy/boss/l3/states/Boss3SwordSpinState.gd
## 剑术：旋转攻击（地面突进旋转）
extends Boss3State
class_name Boss3SwordSpinState

var _spin_distance_left: float = 0.0
var _spinning: bool = false

func enter(_msg: Dictionary = {}) -> void:
	super()
	_face_player()
	boss.animated_sprite.play("sword_spin")
	boss.sword_hit_box.set_deferred("monitoring", true)
	_spin_distance_left = boss.data.sword_spin_distance
	_spinning = true
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * boss.data.sword_spin_speed_multiplier

func update(_delta: float) -> void:
	if _spinning:
		_spin_distance_left -= abs(boss.velocity.x * _delta)
		if _spin_distance_left <= 0.0:
			_spinning = false
			boss.velocity.x = 0.0
			boss.sword_hit_box.set_deferred("monitoring", false)
	elif not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")

func physics_update(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func exit() -> void:
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.velocity.x = 0.0
