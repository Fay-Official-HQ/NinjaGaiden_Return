extends BossAIComponent
class_name BossAIComponent_2

## 决策间隔（秒），AI 每隔多久决定一次下一个动作
const DECISION_COOLDOWN: float = 2.0

func _ready() -> void:
	_decision_timer = DECISION_COOLDOWN

func _process(delta: float) -> void:
	if boss.is_dead:
		return

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = DECISION_COOLDOWN
		_make_decision()


## 决策逻辑：未来在这里加更多状态分支
func _make_decision() -> void:
	if not boss.player_ref:
		_pending_action = ""
		return

	# 目前只有一个飞行状态，后续可扩展
	_pending_action = "BossFlyState"
