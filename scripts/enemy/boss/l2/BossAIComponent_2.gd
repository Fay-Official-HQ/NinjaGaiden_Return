extends BossAIComponent
class_name BossAIComponent_2

const STATE_ORDER: Array[String] = [
	"BossFlyState",
	"BossFireballState",
	"BossFlameState",
	"BossRushState",
	"BossDownRushState",
	"BossUpRushState",
	"BossSpineState",
]

var _next_state_index: int = 1
var _spine_forced: bool = false

## 返回下一个应切换的状态
## HP<21 时尖刺进入循环，首次低于21时必定强制触发一次
func request_decision() -> String:
	# 首次血量低于阈值 → 强制触发尖刺
	if boss.current_hp < boss.data.spine_hp_threshold and not _spine_forced:
		_spine_forced = true
		return "BossSpineState"

	var action = STATE_ORDER[_next_state_index]
	_next_state_index = (_next_state_index + 1) % STATE_ORDER.size()

	# 血量≥阈值时跳过尖刺状态
	if boss.current_hp >= boss.data.spine_hp_threshold and action == "BossSpineState":
		action = STATE_ORDER[_next_state_index]
		_next_state_index = (_next_state_index + 1) % STATE_ORDER.size()

	return action

## 供轮询（等价于 request_decision）
func get_next_action() -> String:
	return request_decision()
