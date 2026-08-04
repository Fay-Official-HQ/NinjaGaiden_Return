extends BossState
class_name Boss4IdleState

## ============================================================
## BOSS4 待机状态
## 建筑 BOSS 原地不动，骷髅头播放 idle 动画，
## 等待 attack_interval 秒后切换为攻击状态（攻击循环）
## ============================================================

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_timer = 0.0
	# 骷髅头播放待机动画
	var head = boss.get_node_or_null("Visual/HeadAnimatedSprite2D") as AnimatedSprite2D
	if head and head.sprite_frames and head.sprite_frames.has_animation("idle"):
		head.play("idle")


func update(delta: float) -> void:
	# 始终面朝玩家
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)

	var data: BossData_4 = boss.data as BossData_4
	var interval: float = data.attack_interval if data else 3.0
	_timer += delta
	if _timer >= interval:
		# 决策交给 AI 组件：决定切换哪个攻击状态
		var next: String = boss.ai_component.request_decision() if boss.ai_component else "BossAttackState"
		state_machine.change_state_by_name(next)
