# res://scripts/enemy/boss/l3/states/Boss3RunState.gd
## 奔跑状态：纯动画控制器，移动由 HandsComponent 统一处理
extends Boss3State
class_name Boss3RunState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("run")
