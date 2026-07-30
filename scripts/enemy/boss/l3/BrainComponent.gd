# res://scripts/enemy/boss/l3/BrainComponent.gd
## 大脑组件：根据战场信息更新策略 → 生成按键信号
## 替换旧 BossAiComponent_3，实现"真人玩家"式的决策
class_name BrainComponent

# ── 策略枚举（5 策略） ──
enum Strategy { OFFENSIVE, DEFENSIVE, RANGED, EVASIVE, NEUTRAL }
var current_strategy: Strategy = Strategy.NEUTRAL

var input_pkg: InputPackage

# ── 决策参数（可通过 BossData_3 配置） ──
var decision_interval: float = 0.3      # 策略更新间隔（秒）
var decision_timer: float = 0.0
var reaction_delay: float = 0.08        # 反应延迟（秒），模拟真人
var reaction_timer: float = 0.0

# ── 走走停停参数 ──
var _walk_timer: float = 0.0
var _rest_timer: float = 0.0
var _is_resting: bool = false

# ── 踱步参数（NEUTRAL 策略用） ──
var _pacing_timer: float = 0.0
# ── 试探策略动作计时器 ──
var _neutral_action_timer: float = 0.0

# ── 策略距离阈值 ──
var offensive_range: float = 150.0
var defensive_range: float = 120.0
var ranged_range: float = 250.0
var evasive_hp_ratio: float = 0.3

# ── 当前帧缓存 ──
var _eye: EyeComponent
var _boss: Boss3
var _player: Player

# ── 动作冷却 ──
var _attack_cooldown: float = 0.0
var _ninjutsu_cooldown: float = 0.0
var _sword_cooldown: float = 0.0
var _block_cooldown: float = 0.0

# ── 连击参数 ──
var _combo_hits_remaining: int = 0

# ── 下蹲参数 ──
var _crouch_timer: float = 0.0

# ── 墙壁边缘逃脱参数 ──
## Marker2DLeft X=580，Marker2DRight X=961（场景边界参考）
const WALL_EDGE_LEFT_X: float = 620.0   # 接近左墙阈值
const WALL_EDGE_RIGHT_X: float = 920.0  # 接近右墙阈值
const ESCAPE_DIST_THRESHOLD: float = 200.0  # 触发逃脱的玩家距离阈值
var _escape_cooldown: float = 0.0       # 逃脱冷却，避免连续触发

## 平台边缘停留帧数计数器（防抖动）
var _edge_stuck_frames: int = 0
## 边缘逃离后强制保持方向的剩余帧数，防止策略立刻走回边缘造成抖动
var _edge_escape_frames: int = 0

func initialize(boss: Boss3, input_pkg_ref: InputPackage) -> void:
	_boss = boss
	_player = boss.player_ref
	input_pkg = input_pkg_ref
	decision_timer = decision_interval
	# 从 BossData_3 读取配置参数
	if boss.data is BossData_3:
		var d = boss.data
		decision_interval = d.ai_decision_interval
		reaction_delay = d.ai_reaction_delay
		offensive_range = d.ai_offensive_range
		defensive_range = d.ai_defensive_range
		ranged_range = d.ai_ranged_range
		# 读取逃避策略阈值
		evasive_hp_ratio = d.ai_evasive_hp_ratio

## 每帧调用：更新策略 → 填充 InputPackage
func update(delta: float, eye: EyeComponent) -> void:
	if not _boss or _boss.is_dead or not _player:
		return

	_eye = eye

	# 更新冷却
	_attack_cooldown = max(0.0, _attack_cooldown - delta)
	_ninjutsu_cooldown = max(0.0, _ninjutsu_cooldown - delta)
	_sword_cooldown = max(0.0, _sword_cooldown - delta)
	_block_cooldown = max(0.0, _block_cooldown - delta)
	_escape_cooldown = max(0.0, _escape_cooldown - delta)

	# 1. 更新策略（每 decision_interval 秒一次）
	decision_timer -= delta
	if decision_timer <= 0.0:
		decision_timer = decision_interval
		_update_strategy()

	# 2. 清空旧按键
	input_pkg.clear()

	# 3. 移动：每帧生成，无反应延迟
	_generate_movement(delta)

	# 4. 动作：有反应延迟
	reaction_timer -= delta
	if reaction_timer <= 0.0:
		reaction_timer = reaction_delay
		_generate_action()


## ── 策略切换（优先级从高到低） ──
## EVASIVE > DEFENSIVE > RANGED > OFFENSIVE > NEUTRAL
func _update_strategy() -> void:
	var info = _eye.info
	var dist = info.get("distance_x", 999.0)
	var player_attacking = info.get("player_is_attacking", false)
	var boss_hp_ratio = info.get("boss_hp_ratio", 1.0)
	var cornered = _boss.wall_stuck_frames > 0
	var boss_x = _boss.global_position.x
	var at_wall_edge = boss_x < WALL_EDGE_LEFT_X or boss_x > WALL_EDGE_RIGHT_X
	var new_strategy: Strategy

	if at_wall_edge and dist < defensive_range * 1.5:
		# 接近墙壁边缘且玩家在附近 → 抢先切逃避，防止被困
		new_strategy = Strategy.EVASIVE
	elif boss_hp_ratio < evasive_hp_ratio or cornered:
		new_strategy = Strategy.EVASIVE
	elif dist < defensive_range and player_attacking:
		new_strategy = Strategy.DEFENSIVE
	elif dist > ranged_range:
		new_strategy = Strategy.RANGED
	elif dist < offensive_range and not player_attacking:
		new_strategy = Strategy.OFFENSIVE
	else:
		new_strategy = Strategy.NEUTRAL

	if new_strategy != current_strategy:
		current_strategy = new_strategy
		var names = ["进攻OFFENSIVE", "防御DEFENSIVE", "远程RANGED", "逃避EVASIVE", "试探NEUTRAL"]
		print("【策略切换】", names[current_strategy])


# ═══════════════════════════════════════════════
# 移动生成（每帧执行，无延迟）
# ═══════════════════════════════════════════════

func _generate_movement(delta: float) -> void:
	var info = _eye.info
	var dist = info.get("distance_x", 999.0)
	var at_edge = info.get("is_at_edge", false)

	match current_strategy:
		Strategy.OFFENSIVE:
			_generate_movement_offensive(delta, dist)
		Strategy.DEFENSIVE:
			_generate_movement_defensive(dist)
		Strategy.RANGED:
			_generate_movement_ranged(delta, dist)
		Strategy.EVASIVE:
			_generate_movement_evasive(delta, dist)
		Strategy.NEUTRAL:
			_generate_movement_neutral(delta, dist)

	# 平台边缘检测计数器（防抖动）：连续处于边缘超过 4 帧才触发掉头
	if at_edge:
		_edge_stuck_frames += 1
	else:
		_edge_stuck_frames = 0

	if _edge_stuck_frames > 4 and current_strategy != Strategy.EVASIVE:
		input_pkg.move_x = -_get_toward()
		_edge_escape_frames = 12  # ~0.2秒内强制保持该方向，防策略走回边缘

	# 边缘逃离后的方向维持：_edge_escape_frames > 0 时覆盖策略的 move_x，防止抖动
	if _edge_escape_frames > 0:
		input_pkg.move_x = -_get_toward()
		_edge_escape_frames -= 1

	# 平台边缘保护（FloorDetect）：向没地面的方向移动时，强制掉头到安全方向
	# 注意：只改 move_x，不改 velocity。
	# velocity 由 _apply_movement 在 _physics_process 中自然过渡，避免抖动。
	# EVASIVE 策略跳过此保护，避免掉头冲向玩家；靠跳跃跨过边缘。
	if current_strategy != Strategy.EVASIVE and _boss.floor_detect_right and _boss.floor_detect_left:
		if input_pkg.move_x > 0 and not _boss.floor_detect_right.is_colliding():
			input_pkg.move_x = -1
		elif input_pkg.move_x < 0 and not _boss.floor_detect_left.is_colliding():
			input_pkg.move_x = 1

	# 墙壁保护（WallDetect 预检测）：前方有墙，禁止往墙移动
	if input_pkg.move_x < 0 and _boss.wall_detect_left.is_colliding():
		input_pkg.move_x = 0
	if input_pkg.move_x > 0 and _boss.wall_detect_right.is_colliding():
		input_pkg.move_x = 0


func _generate_movement_offensive(delta: float, dist: float) -> void:
	var toward = _get_toward()
	if dist > 200.0:
		input_pkg.move_x = toward             # 快速冲刺接近
	elif dist > 100.0:
		input_pkg.move_x = toward             # 正常逼近
	elif dist > 40.0:
		_handle_stop_and_go(delta, dist)      # 走走停停
	else:
		input_pkg.move_x = -toward            # 太近了退一步

	# 贴脸时偶尔下蹲（为下蹲攻击做准备）
	if dist < 40.0 and _boss.is_on_floor():
		_crouch_timer -= delta
		if _crouch_timer <= 0.0:
			if randf() < 0.35:
				input_pkg.move_y = -1
				_crouch_timer = randf_range(0.3, 0.8)
			else:
				_crouch_timer = randf_range(0.1, 0.3)


func _generate_movement_defensive(dist: float) -> void:
	var toward = _get_toward()
	if dist < 40.0:
		input_pkg.move_x = -toward             # 快速后退
	elif dist < 80.0:
		input_pkg.move_x = -toward             # 缓慢后退
	elif dist < 120.0:
		pass                                   # 站住，等待玩家出招
	else:
		input_pkg.move_x = toward              # 稍靠近但不过界


func _generate_movement_ranged(delta: float, dist: float) -> void:
	var toward = _get_toward()
	if dist > 250.0:
		input_pkg.move_x = toward              # 缓慢靠近到射程内
	elif dist < 150.0:
		input_pkg.move_x = -toward             # 快速后退保持距离
	else:
		_handle_stop_and_go(delta, dist)       # 左右踱步保持 180~220px


func _generate_movement_evasive(delta: float, dist: float) -> void:
	var toward = _get_toward()
	var boss_x = _boss.global_position.x
	var at_wall_edge = boss_x < WALL_EDGE_LEFT_X or boss_x > WALL_EDGE_RIGHT_X

	# ── 墙壁边缘：朝反方向冲，准备逃离 ──
	if at_wall_edge:
		var escape_dir = 1 if boss_x < WALL_EDGE_LEFT_X else -1
		input_pkg.move_x = escape_dir
	# 墙角被困 → 朝玩家移动以脱离墙角
	elif _boss.wall_stuck_frames > 0:
		input_pkg.move_x = toward
	else:
		# 始终远离玩家
		input_pkg.move_x = -toward

	# 到达安全距离时偶尔侧移躲避直线攻击
	if dist >= 200.0:
		_pacing_timer -= delta
		if _pacing_timer <= 0.0:
			_pacing_timer = randf_range(0.3, 0.8)


func _generate_movement_neutral(_delta: float, dist: float) -> void:
	var toward = _get_toward()
	# 460px 封闭房间，保持较远距离站位观察
	if dist < 80.0:
		input_pkg.move_x = -toward           # 太近了，稍后退
	else:
		input_pkg.move_x = 0                 # 站住不动，观察玩家


# ═══════════════════════════════════════════════
# 动作生成（有反应延迟，每 reaction_delay 秒执行一次）
# ═══════════════════════════════════════════════

func _generate_action() -> void:
	var info = _eye.info
	var dist = info.get("distance_x", 999.0)
	var player_attacking = info.get("player_is_attacking", false)

	match current_strategy:
		Strategy.OFFENSIVE:
			_generate_action_offensive(info, dist, player_attacking)
		Strategy.DEFENSIVE:
			_generate_action_defensive(info, dist, player_attacking)
		Strategy.RANGED:
			_generate_action_ranged(info, dist)
		Strategy.EVASIVE:
			_generate_action_evasive(info, dist)
		Strategy.NEUTRAL:
			_generate_action_neutral(info, dist)

	# 通用忍术：远程策略不放忍术，其他策略可放
	if current_strategy != Strategy.RANGED and _ninjutsu_cooldown <= 0.0 and randf() < 0.08:
		_choose_ninjutsu_by_position()
		_ninjutsu_cooldown = 1.5


func _generate_action_offensive(info: Dictionary, dist: float, player_attacking: bool) -> void:

	# ── 近战忍术：棱刃（近身对拼专属，去除头顶位置限制） ──
	if dist < 80.0 and _ninjutsu_cooldown <= 0.0 and randf() < 0.25:
		input_pkg.ninjutsu_edge_blade = true
		_ninjutsu_cooldown = 1.5

	# ── 近战攻击组合（站立/下蹲/跳跃攻击） ──
	if dist < 40.0 and _attack_cooldown <= 0.0 and not player_attacking:
		if _combo_hits_remaining > 0:
			# 续刀 - 随机选攻击类型
			var r = randf()
			if r < 0.45:
				input_pkg.attack = true         # 站立攻击
			elif r < 0.70:
				input_pkg.move_y = -1           # 下蹲（自动接下蹲攻击）
				input_pkg.attack = true
			else:
				input_pkg.jump = true           # 跳跃
			_combo_hits_remaining -= 1
			_attack_cooldown = 0.3
		elif randf() < 0.35:
			# 开始新连击（随机 1~3 刀）
			_combo_hits_remaining = randi_range(0, 2)
			input_pkg.attack = true
			_attack_cooldown = 0.3
	else:
		_combo_hits_remaining = 0  # 超出范围重置连击

	# 玩家不在同一水平线时释放忍术（火焰/火球/回旋镖/棱刃-兜底）
	var dist_y = info.get("distance_y", 0.0)
	if abs(dist_y) > 25.0 and _ninjutsu_cooldown <= 0.0:
		if randf() < 0.35:
			_choose_ninjutsu_by_position()
			_ninjutsu_cooldown = 1.2

	# 剑术：根据距离选择
	if _sword_cooldown <= 0.0:
		var player_in_air = not info.get("player_is_on_floor", true)
		if player_in_air and dist < 100.0:
			# 玩家在空中 → 上挑
			if randf() < 0.35:
				input_pkg.sword_uppercut = true
				_sword_cooldown = 1.0
		elif dist < 60.0:
			# 近距离 → 旋转
			if randf() < 0.35:
				input_pkg.sword_spin = true
				_sword_cooldown = 1.5
		elif dist < 120.0:
			# 中距离 → 前冲
			if randf() < 0.25:
				input_pkg.sword_dash = true
				_sword_cooldown = 1.2

	# 跳跃追击（玩家在空中时）
	if not info.get("player_is_on_floor", true) and dist < 120.0:
		if randf() < 0.25:
			input_pkg.jump = true

	# 飞天下劈 combo（FlightToTop → SwordDownslash）
	if dist < 200.0 and dist > 60.0 and _sword_cooldown <= 0.0:
		if randf() < 0.12:
			input_pkg.fly_to_top = true
			_sword_cooldown = 2.0

	# 远距离时偶尔放忍术
	if dist > 150.0 and _ninjutsu_cooldown <= 0.0:
		if randf() < 0.1:
			_choose_ninjutsu_by_position()
			_ninjutsu_cooldown = 1.5


func _generate_action_defensive(info: Dictionary, dist: float, player_attacking: bool) -> void:
	# 格挡
	if _block_cooldown <= 0.0 and dist < 120.0:
		if player_attacking and randf() < 0.7:
			input_pkg.block = true
			_block_cooldown = 0.3
		elif not player_attacking and randf() < 0.3:
			# 玩家未攻击时也偶尔格挡（防突袭）
			input_pkg.block = true
			_block_cooldown = 0.5

	# 向后跳跃躲避
	if dist < 40.0:
		if player_attacking and randf() < 0.5:
			input_pkg.jump = true
		elif not player_attacking and randf() < 0.2:
			input_pkg.jump = true

	# 反击：玩家攻击后摇中用忍术或剑术
	if not player_attacking and dist < 50.0:
		# 玩家在垂直方向偏移时优先释放忍术
		var dist_y = info.get("distance_y", 0.0)
		if abs(dist_y) > 25.0 and _ninjutsu_cooldown <= 0.0 and randf() < 0.4:
			_choose_ninjutsu_by_position()
			_ninjutsu_cooldown = 1.5
		elif _sword_cooldown <= 0.0 and randf() < 0.25:
			input_pkg.sword_uppercut = true
			_sword_cooldown = 1.0
		if _attack_cooldown <= 0.0 and dist < 40.0 and randf() < 0.2:
			input_pkg.attack = true
			_attack_cooldown = 0.8


func _generate_action_ranged(info: Dictionary, dist: float) -> void:
	# 投掷飞镖：远程消耗（使用数据驱动范围）
	if dist >= _boss.data.throw_min_range and dist <= _boss.data.throw_max_range and randf() < 0.35:
		input_pkg.throw_dart = true

	# 玩家在 Boss 上方时跳起追击
	if info.get("boss_is_on_floor", true) and info.get("distance_y", 0.0) < -50.0 and randf() < 0.15:
		input_pkg.jump = true

	# 被近距离突袭时格挡
	if dist < 80.0 and _block_cooldown <= 0.0 and randf() < 0.3:
		input_pkg.block = true
		_block_cooldown = 0.5


func _generate_action_evasive(info: Dictionary, dist: float) -> void:
	var is_cornered = _boss.wall_stuck_frames > 0
	var boss_x = _boss.global_position.x
	var at_wall_edge = boss_x < WALL_EDGE_LEFT_X or boss_x > WALL_EDGE_RIGHT_X

	# ── 墙壁边缘逃脱：被堵在墙壁边缘且玩家接近时，强制冲向另一侧 ──
	if at_wall_edge and dist < ESCAPE_DIST_THRESHOLD and _escape_cooldown <= 0.0:
		_trigger_wall_escape(boss_x)
		return

	# 墙角被困：不要跳墙，改为移动挣脱
	if not is_cornered and randf() < 0.7:
		input_pkg.jump = true

	# 格挡保命
	if _block_cooldown <= 0.0 and randf() < 0.6:
		input_pkg.block = true
		_block_cooldown = 0.3

	# 忍术干扰
	if _ninjutsu_cooldown <= 0.0 and randf() < 0.2:
		_choose_ninjutsu_by_position()
		_ninjutsu_cooldown = 1.5

	# ── 绝境反击
	if dist < 60.0 and not info.get("player_is_attacking", false):
		if _sword_cooldown <= 0.0 and randf() < 0.2:
			_choose_sword_skill_by_distance(dist)
			_sword_cooldown = 1.0


func _generate_action_neutral(_info: Dictionary, dist: float) -> void:
	# 试探策略：以待机 idle 为主，偶尔回旋镖骚扰或飞行下劈
	_neutral_action_timer -= 1.0  # 每调用一次减 1（reaction_delay=0.08s 等效~0.08s）
	if _neutral_action_timer > 0.0:
		return

	# 下次动作间隔：idle 为主，间隔较长（~2~5 秒）
	_neutral_action_timer = randf_range(25.0, 60.0)

	var roll = randf()
	if roll < 0.30:
		# 30%: 继续 idle 观察
		_neutral_action_timer = randf_range(15.0, 40.0)
		return
	elif roll < 0.50:
		# 20%: 投掷回旋镖试探
		if dist > 80.0 and dist < 350.0:
			input_pkg.ninjutsu_boomerang = true
			_neutral_action_timer = randf_range(20.0, 40.0)
		else:
			_neutral_action_timer = randf_range(10.0, 25.0)
	elif roll < 0.65:
		# 15%: 根据位置释放忍术（火焰/火球/棱刃）
		if _ninjutsu_cooldown <= 0.0:
			_choose_ninjutsu_by_position()
			_ninjutsu_cooldown = 2.0
		_neutral_action_timer = randf_range(20.0, 40.0)
	elif roll < 0.85:
		# 20%: 飞行下劈（FlightToTop → SwordDownslash）
		input_pkg.fly_to_top = true
		_neutral_action_timer = randf_range(20.0, 40.0)
	else:
		# 15%: 飞向另一侧平台观察玩家
		var dir_to_player = sign(_player.global_position.x - _boss.global_position.x)
		if dir_to_player > 0:
			input_pkg.fly_to_left = true
		else:
			input_pkg.fly_to_right = true
		_neutral_action_timer = randf_range(10.0, 20.0)


# ═══════════════════════════════════════════════
# 走走停停逻辑
# ═══════════════════════════════════════════════

func _handle_stop_and_go(delta: float, dist: float) -> void:
	if _is_resting:
		_rest_timer -= delta
		if _rest_timer <= 0.0:
			_is_resting = false
			# 进攻策略下走得更久停得更短
			if current_strategy == Strategy.OFFENSIVE:
				_walk_timer = randf_range(0.8, 1.5)
			else:
				_walk_timer = randf_range(0.8, 2.5)
		else:
			input_pkg.move_x = 0
	else:
		_walk_timer -= delta
		if _walk_timer <= 0.0:
			_is_resting = true
			# 进攻策略休息极短（0.05~0.15s）
			if current_strategy == Strategy.OFFENSIVE:
				_rest_timer = randf_range(0.05, 0.15)
			else:
				_rest_timer = randf_range(0.1, 0.3)
			input_pkg.move_x = 0
		else:
			input_pkg.move_x = 1

	# 走到近处提前停一下观察
	if not _is_resting and dist < 60.0 and _walk_timer > 0.3:
		_walk_timer = 0.0


# ═══════════════════════════════════════════════
# 剑术选择（根据距离和局势）
# ═══════════════════════════════════════════════

func _choose_sword_skill_by_distance(dist: float) -> void:
	var player_in_air = not _eye.info.get("player_is_on_floor", true)

	if player_in_air and dist < 100.0:
		# 玩家在空中 → 上挑
		input_pkg.sword_uppercut = true
	elif dist < 30.0:
		# 贴脸 → 旋转
		input_pkg.sword_spin = true
	elif dist < 60.0:
		# 近距 → 旋转或上挑
		if randf() < 0.6:
			input_pkg.sword_spin = true
		else:
			input_pkg.sword_uppercut = true
	elif dist < 120.0:
		# 中距 → 前冲
		input_pkg.sword_dash = true
	else:
		# 远距 → 前冲接近
		if dist < 180.0:
			input_pkg.sword_dash = true
		# 太远不使用剑术


# ═══════════════════════════════════════════════
# 忍术选择（根据玩家相对位置智能选择）
# ═══════════════════════════════════════════════

func _choose_ninjutsu_by_position() -> void:
	var info = _eye.info
	var dist_x = info.get("distance_x", 999.0)
	var dist_y = info.get("distance_y", 0.0)

	# 优先级 1: 玩家在正上方（dist_y < -50 且 水平偏移 < 50）
	if dist_y < -50.0 and dist_x < 50.0:
		input_pkg.ninjutsu_edge_blade = true
		return

	# 优先级 2: 玩家在上方（dist_y < -25），非正上方 → 火焰（斜上方三团）
	if dist_y < -25.0:
		input_pkg.ninjutsu_fire = true
		return

	# 优先级 3: 玩家在下方（dist_y > 25）
	if dist_y > 25.0:
		# 50% 跳跃后释放火球，50% 直接地面火球
		if randf() < 0.4 and _boss.is_on_floor():
			input_pkg.jump = true
		input_pkg.ninjutsu_fireball = true
		return

	# 优先级 4: 同一水平线 → 回旋镖
	input_pkg.ninjutsu_boomerang = true


## 返回指向玩家的方向（1=右, -1=左），基于实际位置差，不受 _face_player 翻转影响
func _get_toward() -> int:
	if not _boss.player_ref:
		return 1
	return 1 if _boss.player_ref.global_position.x > _boss.global_position.x else -1


# ═══════════════════════════════════════════════
# 墙壁边缘逃脱
# ═══════════════════════════════════════════════

## 墙壁边缘逃脱：使用剑术或飞行强制冲向玩家另一侧
func _trigger_wall_escape(boss_x: float) -> void:
	_escape_cooldown = 1.5  # 冷却1.5秒，防止连续触发

	# 确定逃脱方向：左墙→右，右墙→左
	var escaping_right = boss_x < WALL_EDGE_LEFT_X

	# 场景约束：左墙 Marker2DLeft(X=580)，右墙 Marker2DRight(X=961)
	# 使用剑术前冲或飞行，强制穿过玩家到达另一侧

	# 优先使用剑术前冲（地面快速穿过玩家，无视剑术冷却）
	if _boss.is_on_floor():
		input_pkg.sword_dash = true
		_sword_cooldown = 2.0
	elif randf() < 0.4:
		# 飞行到另一侧 Marker2D
		if escaping_right:
			input_pkg.fly_to_right = true
		else:
			input_pkg.fly_to_left = true
	else:
		# 跳跃+冲刺逃离
		input_pkg.jump = true
		# move_x 已由 _generate_movement_evasive 设置为逃离方向
