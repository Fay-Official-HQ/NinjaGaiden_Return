# res://scripts/enemy/boss/l3/BossAiComponent_3.gd
extends Node
class_name BossAIComponent3

var boss: Boss3

## 当前循环索引
var _cycle_index: int = 0
## 已缓存的下一个动作
var _pending_action: String = ""
## 决策冷却计时器
var _decision_timer: float = 0.0

func initialize(owner_boss: Boss3) -> void:
	boss = owner_boss
	_decision_timer = boss.data.ai_decision_interval
	request_next_action()

func _process(delta: float) -> void:
	if not boss or boss.is_dead:
		return
	if not boss.state_machine.current_state is Boss3IdleState:
		return
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = boss.data.ai_decision_interval
		request_next_action()

## 推进循环索引并缓存下一个动作
func request_next_action() -> void:
	if not boss or not boss.data:
		_pending_action = ""
		return
	var cycle = _get_current_cycle()
	if cycle.is_empty():
		_pending_action = ""
		return
	_pending_action = cycle[_cycle_index]
	_cycle_index = (_cycle_index + 1) % cycle.size()
	print("【假隼龙AI】预缓存动作: ", _pending_action)

## IdleState 每帧调用：返回下一个动作（消费后清空）
func get_next_action() -> String:
	var action = _pending_action
	_pending_action = ""
	return action

## 返回当前应使用的循环列表
func _get_current_cycle() -> Array[String]:
	if boss.current_hp <= boss.data.phase2_hp_threshold:
		return boss.data.ai_state_cycle_phase2
	return boss.data.ai_state_cycle

## 强制下次执行指定动作
func force_action(action_name: String) -> void:
	_pending_action = action_name

func _get_player_distance_x() -> float:
	if not boss.player_ref:
		return 9999.0
	return abs(boss.player_ref.global_position.x - boss.global_position.x)
