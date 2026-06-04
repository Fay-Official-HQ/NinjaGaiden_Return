# res://scripts/player/states/AirNinjutsuState.gd
extends State

class_name AirNinjutsuState

var is_imbalance: bool = false

func enter(msg: Dictionary = {}) -> void:
	is_imbalance = msg.get("imbalance", false)
	player.animation.play("air_ninjutsu")
	player.ninjutsu.cast_ninjutsu()

func update(_delta: float) -> void:
	# 如果空中施法还没结束就落地了，直接中断动作恢复站立
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
		return

	# 动画结束，退回到下落状态，并交还失衡标记
	var sprite = player.animation.sprite
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
