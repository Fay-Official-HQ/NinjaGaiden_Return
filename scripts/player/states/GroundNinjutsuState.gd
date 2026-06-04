# res://scripts/player/states/GroundNinjutsuState.gd
extends State

class_name GroundNinjutsuState

var _has_cast: bool = false

func enter(_msg: Dictionary = {}) -> void:
	player.movement.stop()
	player.animation.play("ground_ninjutsu")
	_has_cast = false

func update(_delta: float) -> void:
	var sprite = player.animation.sprite
	if not _has_cast and sprite.animation == "ground_ninjutsu" and sprite.frame >= 1:
		_has_cast = true
		player.ninjutsu.cast_ninjutsu()
	if sprite.animation == "ground_ninjutsu" and not sprite.is_playing():
		if player.input.move_direction != 0:
			state_machine.change_state(player.run_state)
		else:
			state_machine.change_state(player.idle_state)

func physics_update(_delta: float) -> void:
	player.movement.stop() # 持续锁死 X 轴
	
	# 防错边缘判定
	if not player.is_on_floor():
		state_machine.change_state(player.fall_state, {"imbalance": true})
		return
		
	player.move_and_slide()
