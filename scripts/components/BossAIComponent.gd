extends Node
class_name BossAIComponent

var boss: Boss
var _decision_timer: float = 0.0
var _pending_action: String = ""
var _state_index: int = 0
#决策时间
const DECISION_INTERVAL: float = 0.5
## 轮流切换的状态列表，按顺序循环
## 空字符串 "" 表示继续 Idle（待机巡逻）
const STATE_CYCLE: Array[String] = ["", "BossWalkState", "BossSlashState", "BossLightningState", "BossJumpState", "BossGroundWaveState", "BossRushState", "BossLaserState"]

func initialize(owner_boss: Boss) -> void:
	boss = owner_boss
	_decision_timer = DECISION_INTERVAL

func _process(delta: float) -> void:
	if boss.is_dead:
		return
	if boss.state_machine.current_state and not (boss.state_machine.current_state is BossIdleState):
		return
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = DECISION_INTERVAL
		_make_decision()

## 每3秒从列表中取出下一个状态
func _make_decision() -> void:
	if not boss.player_ref:
		_pending_action = ""
		return
	_pending_action = STATE_CYCLE[_state_index]
	_state_index = (_state_index + 1) % STATE_CYCLE.size()
	if _pending_action == "BossJumpState" and boss.current_hp >= 32:
		_pending_action = ""
	print("【BossAI】决策结果: ", _pending_action if _pending_action != "" else "继续巡逻")

## IdleState 每帧调用，获取待执行的动作
func get_next_action() -> String:
	var action = _pending_action
	_pending_action = ""
	return action
