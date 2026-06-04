# res://scripts/player/states/GroundNinjutsuState.gd
extends State

class_name GroundNinjutsuState

func enter(_msg: Dictionary = {}) -> void:
	print("【调试】进入 GroundNinjutsuState")
	# 瞬间停止移动，施加施法硬直
	player.movement.stop()
	player.animation.play("ground_ninjutsu")
	print("【调试】调用 player.ninjutsu.cast_ninjutsu()")
	player.ninjutsu.cast_ninjutsu()

func update(_delta: float) -> void:
	var sprite = player.animation.sprite
	if sprite.animation == "ground_ninjutsu" and not sprite.is_playing():
		# 动画结束，根据当前按键方向决定恢复状态
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
