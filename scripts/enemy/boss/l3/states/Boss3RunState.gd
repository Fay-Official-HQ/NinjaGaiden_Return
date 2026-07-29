# res://scripts/enemy/boss/l3/states/Boss3RunState.gd
extends Boss3State
class_name Boss3RunState

var _should_stop: bool = false

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("run")
	_should_stop = false
	# 如果已经在玩家 30px 内，下次 update 直接结束
	if boss.player_ref:
		var dist = abs(boss.global_position.x - boss.player_ref.global_position.x)
		_should_stop = dist <= boss.data.ai_close_distance

func update(_delta: float) -> void:
	if not boss.player_ref:
		state_machine.change_state_by_name("Boss3IdleState")
		return
	if _should_stop:
		boss.velocity.x = 0.0
		state_machine.change_state_by_name("Boss3IdleState")
		return

func physics_update(delta: float) -> void:
	if not boss.player_ref:
		return
	# 始终朝向玩家行走
	var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.velocity.x = dir * boss.data.run_speed
	boss.set_facing_direction(dir)
	_apply_gravity(delta)
	boss.move_and_slide()
	# 到达玩家身前 30 像素 → 停
	var dist = abs(boss.global_position.x - boss.player_ref.global_position.x)
	if dist <= boss.data.ai_close_distance:
		boss.velocity.x = 0.0
		state_machine.change_state_by_name("Boss3IdleState")
		return

	# 从平台边缘坠落 → 转入下落状态
	if not boss.is_on_floor() and boss.velocity.y > 0:
		state_machine.change_state_by_name("Boss3FallState")

func exit() -> void:
	super()
	boss.velocity.x = 0.0

func _apply_gravity(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
