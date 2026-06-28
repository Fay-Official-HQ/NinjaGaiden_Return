extends Node
class_name BossAIComponent

var boss: Boss
var _decision_timer: float = 0.0
var _pending_action: String = ""
## 用于 Combo 压制（地波命中后强制接激光）
var _force_next_action: String = ""
## 忍术读指令：记录忍术释放时间戳
var _ninjutsu_timestamps: Array[float] = []
var _actions_since_lightning: int = 0

const CLOSE_DIST: float = 50.0
const MEDIUM_DIST: float = 150.0
const NINJUTSU_WINDOW: float = 5.0
const NINJUTSU_THRESHOLD: int = 3
const OVERDRIVE_DURATION: float = 5.0
const LIGHTNING_COOLDOWN_ACTIONS: int = 3

func initialize(owner_boss: Boss) -> void:
	boss = owner_boss
	_decision_timer = _get_decision_interval()
	_setup_ninjutsu_tracking()

func _process(delta: float) -> void:
	if boss.is_dead:
		return
	if boss.state_machine.current_state and not (boss.state_machine.current_state is BossIdleState):
		return
	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = _get_decision_interval()
		_make_decision()

## 根据血量阶段返回决策间隔
func _get_decision_interval() -> float:
	var hp = boss.current_hp
	if hp <= 10:
		return 0.2
	elif hp <= 23:
		return 0.5
	return 0.8

## 核心决策：先检查强制动作，否则计算权重摇号
func _make_decision() -> void:
	if not boss.player_ref:
		_pending_action = ""
		return
	if _force_next_action != "":
		_pending_action = _force_next_action
		_force_next_action = ""
		print("【BossAI】强制动作: ", _pending_action)
		return
	var dist = _get_player_distance_x()
	var weights = _calculate_weights(dist)
	_pending_action = _lottery_pick(weights)
	if _pending_action == "BossLightningState":
		_actions_since_lightning = 0
	elif _pending_action != "":
		_actions_since_lightning += 1
	var log_action = _pending_action if _pending_action != "" else "继续巡逻"
	print("【BossAI】决策结果: ", log_action)

## 条件权重分配：距离分区 → 玩家空中 → 血量阶段
func _calculate_weights(dist: float) -> Dictionary:
	var w = {
		"": 5,
		"BossSlashState": 0,
		"BossRushState": 0,
		"BossJumpState": 0,
		"BossLaserState": 0,
		"BossGroundWaveState": 0,
		"BossWalkState": 0,
		"BossLightningState": 0,
	}
	if dist < CLOSE_DIST:
		w["BossSlashState"] = 35
		w["BossRushState"] = 20
		w["BossJumpState"] = 15
		w["BossWalkState"] = 15
		w["BossGroundWaveState"] = 5
		w["BossLaserState"] = 5
		w[""] = 5
	elif dist < MEDIUM_DIST:
		w["BossRushState"] = 25
		w["BossJumpState"] = 25
		w["BossWalkState"] = 15
		w["BossGroundWaveState"] = 10
		w["BossLaserState"] = 10
		w["BossSlashState"] = 5
		w[""] = 10
	else:
		w["BossLaserState"] = 30
		w["BossGroundWaveState"] = 30
		w["BossRushState"] = 15
		w["BossJumpState"] = 10
		w["BossWalkState"] = 5
		w[""] = 10
	if _is_player_in_air():
		w["BossJumpState"] += 15
	if boss.current_hp < 24 and _actions_since_lightning >= LIGHTNING_COOLDOWN_ACTIONS:
		if boss.current_hp <= 10:
			w["BossLightningState"] = 35
		else:
			w["BossLightningState"] = 15
	for key in w:
		w[key] = max(0, w[key])
	return w

## 摇号：按权重概率抽取一个动作
func _lottery_pick(weights: Dictionary) -> String:
	var total = 0
	for v in weights.values():
		total += v
	if total <= 0:
		return ""
	var roll = randf() * total
	var cumulative = 0.0
	for action in weights:
		cumulative += weights[action]
		if roll <= cumulative:
			return action
	return ""

func _get_player_distance_x() -> float:
	if not boss.player_ref:
		return 9999.0
	return abs(boss.player_ref.global_position.x - boss.global_position.x)

func _is_player_in_air() -> bool:
	if not boss.player_ref:
		return false
	return not boss.player_ref.is_on_floor()

## IdleState 每帧调用，获取待执行的动作
func get_next_action() -> String:
	var action = _pending_action
	_pending_action = ""
	return action

## 外部调用：强制下次执行指定动作（用于 Combo 压制等）
func force_action(action_name: String) -> void:
	_force_next_action = action_name

func _setup_ninjutsu_tracking() -> void:
	if not boss.player_ref or not boss.player_ref.ninjutsu:
		return
	boss.player_ref.ninjutsu.ninjutsu_used.connect(_on_player_ninjutsu_used)

func _on_player_ninjutsu_used() -> void:
	var now = Time.get_ticks_msec() / 1000.0
	_ninjutsu_timestamps.append(now)
	var cutoff = now - NINJUTSU_WINDOW
	var count = 0
	for t in _ninjutsu_timestamps:
		if t >= cutoff:
			count += 1
	if count >= NINJUTSU_THRESHOLD:
		_ninjutsu_timestamps = []
		boss.activate_ninjutsu_overdrive()
		print("【BossAI】读指令：5秒内3次忍术，触发格挡金身模式")
