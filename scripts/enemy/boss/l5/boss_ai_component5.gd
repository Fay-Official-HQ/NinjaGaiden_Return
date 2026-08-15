extends BossAIComponent
class_name BossAIComponent_5

## 第5章 Boss 专用 AI：
## 1. 必杀技（轰炸）按固定血线触发：血量依次低于 25/18/10 时各触发一次，
##    全程最多 3 次，优先级最高，不参与评分（触发值在 BossData_5.ai_bomb_trigger_hp）
## 2. 其余攻击（激光/火凤凰/飞踢）按「距离分区 + 垂直对齐 + 玩家移动 + 血量阶段」评分选优
## 3. 全局冷却 + 技能独立冷却，二阶段（低血量）更激进
## 所有阈值/权重/冷却均来自 BossData_5（我需要调试）

## 已触发的轰炸次数（全程最多 3 次）
var _bomb_triggers: int = 0
## 待出现奖励的轰炸序号（第几次轰炸），0 表示无待定奖励
var _pending_bomb_index: int = 0
## 奖励出现延迟倒计时（秒）：轰炸进行中才出现消耗品
var _reward_delay_timer: float = 0.0
## 全局攻击冷却剩余时间（秒）
var _global_cooldown: float = 0.0
## 各技能冷却剩余时间（秒）
var _skill_cooldowns: Dictionary = {}

## 玩家移动追踪
var _player_last_pos: Vector2 = Vector2.INF
var _player_moving: bool = false
var _move_check_timer: float = 0.0


func initialize(owner_boss: Boss) -> void:
	super(owner_boss)
	_player_last_pos = owner_boss.player_ref.global_position if owner_boss.player_ref else Vector2.ZERO


func _process(delta: float) -> void:
	if boss.is_dead:
		return
	# 血线达标立即原地召唤轰炸支援（无需先飞向目标点）
	var data := boss.data as BossData_5
	if data and _try_trigger_bomb(data):
		boss.state_machine.change_state_by_name("BossBombState")
		return
	_update_cooldowns(delta)
	_track_player_movement(delta)
	_update_reward_delay(delta)


## 轰炸奖励延迟出现：轰炸进行中（延迟秒数后）才激活补给消耗品
func _update_reward_delay(delta: float) -> void:
	if _pending_bomb_index <= 0 or _reward_delay_timer <= 0.0:
		return
	_reward_delay_timer -= delta
	if _reward_delay_timer <= 0.0:
		_reveal_bomb_reward(_pending_bomb_index)
		_pending_bomb_index = 0


## 尝试按血线触发必杀技轰炸（全程最多 3 次）：
## 血量低于对应血线时立即触发（无需先飞向目标点），触发成功返回 true。
## 消耗品延迟出现（第1/2次 bomb_reward_delay 秒后，第3次 bomb3_reward3_delay 秒后）；
## 第3次轰炸开始时额外开启士兵波次。
func _try_trigger_bomb(data: BossData_5) -> bool:
	if _bomb_triggers >= data.ai_bomb_trigger_hp.size():
		return false
	# 正在召唤轰炸（播 hongzha 召唤动画）期间不重复触发，避免连续血线打断召唤
	if boss.state_machine.current_state and boss.state_machine.current_state.name == "BossBombState":
		return false
	if boss.current_hp > data.ai_bomb_trigger_hp[_bomb_triggers]:
		return false
	_bomb_triggers += 1
	_pending_bomb_index = _bomb_triggers
	_reward_delay_timer = data.bomb3_reward3_delay if _bomb_triggers == 3 else data.bomb_reward_delay
	if _bomb_triggers == 3:
		_start_soldier_wave(data)
	_global_cooldown = _get_global_cooldown(data)
	print("【BossAI_5】必杀技轰炸触发 第%d次（血量 %d/%d）" % [_bomb_triggers, boss.current_hp, boss.data.max_hp])
	return true


## 第3次轰炸：开启士兵波次生成器（独立挂场景节点，全灭后等 wave_gap 秒出新一波，直到 Boss 死亡）
func _start_soldier_wave(data: BossData_5) -> void:
	var spawner := SoldierWaveSpawner.new()
	spawner.boss = boss
	spawner.paratrooper_max = data.bomb3_paratrooper_count
	spawner.wave_gap = data.bomb3_soldier_wave_gap
	get_tree().current_scene.add_child(spawner)
	print("【BossAI_5】第3次轰炸：士兵波次开启（空降兵上限 %d，波间间隔 %.1f 秒）" % [data.bomb3_paratrooper_count, data.bomb3_soldier_wave_gap])


## 冷却计时：全局冷却与各技能冷却逐帧递减
func _update_cooldowns(delta: float) -> void:
	_global_cooldown = maxf(0.0, _global_cooldown - delta)
	for key in _skill_cooldowns:
		_skill_cooldowns[key] = maxf(0.0, float(_skill_cooldowns[key]) - delta)


## 每 0.1 秒检测一次玩家是否在移动（0.1 秒内位移超过 20px 视为移动中）
func _track_player_movement(delta: float) -> void:
	_move_check_timer -= delta
	if _move_check_timer > 0.0 or not boss.player_ref:
		return
	_move_check_timer = 0.1
	var p := boss.player_ref.global_position
	_player_moving = absf(p.x - _player_last_pos.x) > 20.0 or absf(p.y - _player_last_pos.y) > 20.0
	_player_last_pos = p


## 飞行状态到达目标点后请求下一步动作
func request_decision() -> String:
	var data := boss.data as BossData_5
	if data == null or boss.player_ref == null:
		return "BossFlyState"

	# 1. 必杀技：固定血线触发（优先级最高，全程最多 3 次）
	if _try_trigger_bomb(data):
		return "BossBombState"

	# 2. 全局冷却：间隔内只飞行，防止连续出招
	if _global_cooldown > 0.0:
		return "BossFlyState"

	# 3. 收集战场信息
	var dx := absf(boss.player_ref.global_position.x - boss.global_position.x)
	var dy := absf(boss.player_ref.global_position.y - boss.global_position.y)
	var dist := sqrt(dx * dx + dy * dy)
	var phase2 := boss.current_hp <= boss.data.max_hp * data.ai_phase2_hp_ratio

	# 4. 计算各攻击评分（冷却中的技能不参与）
	var scores := {}
	if _get_cooldown("BossShootState") <= 0.0:
		scores["BossShootState"] = _score_laser(data, dy, dist)
	if _get_cooldown("BossShootBothState") <= 0.0:
		scores["BossShootBothState"] = _score_phoenix(data, dy, dist)
	if _get_cooldown("BossKickState") <= 0.0:
		scores["BossKickState"] = _score_kick(data, dy, dist)

	# 5. 二阶段：所有攻击分数放大（更激进）
	if phase2:
		for key in scores:
			scores[key] *= data.ai_phase2_aggression_multiplier

	# 6. 选最高分
	var best := _pick_best(scores)
	if best == "":
		return "BossFlyState"

	# 7. 记录本次攻击并设置冷却
	_global_cooldown = _get_global_cooldown(data)
	_skill_cooldowns[best] = _get_skill_cooldown(data, best)
	return best


func _get_cooldown(state: String) -> float:
	return float(_skill_cooldowns.get(state, 0.0))


## 血线轰炸附带恢复奖励：每次轰炸只激活一个 ItemGated 补给（先播 wuye 升腾动画，播完才显示本体）
## 第1次轰炸 → Items/ItemGated1，第2次轰炸 → Items/ItemGated2，第3次轰炸 → Items/ItemGated3
## 补给类型与恢复数值取场景中已配置好的值，代码不覆盖用户设置
func _reveal_bomb_reward(bomb_index: int) -> void:
	var reward_path := ""
	match bomb_index:
		1: reward_path = "Items/ItemGated1"
		2: reward_path = "Items/ItemGated2"
		3: reward_path = "Items/ItemGated3"
	if reward_path == "":
		return
	_activate_item_gated(reward_path, bomb_index)


## 激活指定路径的 ItemGated 补给（沿用节点自身配置的类型/数值，仅激活显示）
func _activate_item_gated(node_path: String, index: int) -> void:
	var reward := get_tree().current_scene.get_node_or_null(node_path) as ItemGated
	if reward == null:
		print("【BossAI_5】警告：轰炸奖励节点未找到（%s）" % node_path)
		return
	reward.activate(reward.consumable_type, reward.restore_hp, reward.restore_mp_small, reward.restore_mp_large, reward.restore_tp)
	print("【BossAI_5】轰炸奖励已激活：%s（第%d次轰炸，类型 %d）" % [node_path, index, reward.consumable_type])


## 激光散射：中距离最佳（带追踪但散射幅度大），玩家在下方时更优
func _score_laser(data: BossData_5, dy: float, dist: float) -> float:
	var score := data.ai_laser_base
	if dist < data.ai_dist_close:
		score += data.ai_laser_close_bonus
	elif dist < data.ai_dist_far:
		score += data.ai_laser_mid_bonus
	else:
		score += data.ai_laser_far_bonus
	if dy > data.ai_align_threshold:
		score += data.ai_laser_vertical_bonus
	return score


## 火凤凰：远距离主场，垂直已对齐命中率高，玩家移动时扣分
func _score_phoenix(data: BossData_5, dy: float, dist: float) -> float:
	var score := 0.0
	if dist >= data.ai_dist_far:
		score += data.ai_phoenix_far_bonus
	elif dist >= data.ai_dist_close:
		score += data.ai_phoenix_mid_bonus
	else:
		score += data.ai_phoenix_close_penalty
	if dy < data.ai_align_threshold:
		score += data.ai_phoenix_align_bonus
	else:
		score -= data.ai_phoenix_misalign_penalty
	if _player_moving:
		score -= data.ai_phoenix_move_penalty
	return score


## 飞踢：近距离主场，垂直已对齐命中率高，玩家移动时扣分
func _score_kick(data: BossData_5, dy: float, dist: float) -> float:
	var score := 0.0
	if dist < data.ai_dist_close:
		score += data.ai_kick_close_bonus
	elif dist < data.ai_dist_far:
		score += data.ai_kick_mid_bonus
	else:
		score += data.ai_kick_far_bonus
	if dy < data.ai_align_threshold:
		score += data.ai_kick_align_bonus
	else:
		score -= data.ai_kick_misalign_penalty
	if _player_moving:
		score -= data.ai_kick_move_penalty
	return score


## 选出评分最高的状态
func _pick_best(scores: Dictionary) -> String:
	var best := ""
	var best_score := -INF
	for state in scores:
		if float(scores[state]) > best_score:
			best_score = float(scores[state])
			best = state
	return best


## 各技能独立冷却（秒）
func _get_skill_cooldown(data: BossData_5, state: String) -> float:
	match state:
		"BossShootState": return data.ai_cooldown_laser
		"BossShootBothState": return data.ai_cooldown_phoenix
		"BossKickState": return data.ai_cooldown_kick
	return 0.0


## 全局冷却（二阶段按比例缩减）
func _get_global_cooldown(data: BossData_5) -> float:
	var cd := data.ai_global_cooldown
	if boss.current_hp <= boss.data.max_hp * data.ai_phase2_hp_ratio:
		cd *= data.ai_phase2_cooldown_reduce
	return cd
