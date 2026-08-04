extends BossAIComponent
class_name BossAIComponent_4

## ============================================================
## BOSS4 决策组件（简化版）
## 建筑 BOSS 无复杂决策：唯一的行动是发动攻击（BossAttackState）。
## 攻击时机（attack_interval 计时）由 Boss4IdleState 负责，这里只负责"选哪个攻击状态"，
## 将来如需增加第二种攻击，只需在此按条件返回对应状态名。
## ============================================================

## 返回下一个应切换的状态：BOSS4 唯一攻击状态
func request_decision() -> String:
	return "BossAttackState"

## 供轮询（等价于 request_decision）
func get_next_action() -> String:
	return request_decision()
