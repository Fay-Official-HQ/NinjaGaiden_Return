# res://scripts/player/states/RelaxState.gd
# 放松状态：idle 静止 5 秒无任何输入后进入，与 idle 一样静止站立，动画为 default
# 继承 IdleState 复用全部输入处理逻辑（有输入即恢复正常行动）
extends IdleState

class_name RelaxState

func enter(_msg: Dictionary = {}) -> void:
	player.animation.play("default")
	_no_input_time = 0.0
