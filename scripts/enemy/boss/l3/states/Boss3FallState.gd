# res://scripts/enemy/boss/l3/states/Boss3FallState.gd
## 自由下落状态：纯动画控制器，物理由 HandsComponent 统一处理
extends Boss3State
class_name Boss3FallState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("fall")

func update(_delta: float) -> void:
	if boss.is_on_floor():
		boss.velocity.x = 0.0  # 落地清零水平速度，防滑出抖动
		state_machine.change_state_by_name("Boss3IdleState")
