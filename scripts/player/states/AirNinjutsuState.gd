# res://scripts/player/states/AirNinjutsuState.gd
extends State

class_name AirNinjutsuState

var is_imbalance: bool = false
var _has_cast: bool = false

func enter(msg: Dictionary = {}) -> void:
	is_imbalance = msg.get("imbalance", false)
	player.animation.play("air_ninjutsu")
	_has_cast = false

func update(_delta: float) -> void:
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
		return

	var sprite = player.animation.sprite
	if not _has_cast and sprite.animation == "air_ninjutsu" and sprite.frame >= 1:
		_has_cast = true
		player.ninjutsu.cast_ninjutsu()

	if sprite.animation == "air_ninjutsu" and not sprite.is_playing():
		state_machine.change_state(player.fall_state, {"imbalance": is_imbalance})

func physics_update(_delta: float) -> void:
	var move_dir = player.input.move_direction
	
	# 【核心铁律】空中施法期间绝对不允许转身，保持原有惯性
	if move_dir != 0:
		if move_dir != player.facing_direction:
			is_imbalance = true
			player.velocity.x = move_dir * player.data.walk_speed * player.data.imbalance_speed_factor
		else:
			player.velocity.x = move_dir * player.data.walk_speed
	else:
		player.movement.stop()
		
	player.move_and_slide()
