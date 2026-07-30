# res://scripts/enemy/boss/l3/HandsComponent.gd
## 双手组件：执行大脑的按键信号，驱动物理和状态机
## 职责：移动/跳跃/攻击/忍术/剑术/格挡 的实际执行
class_name HandsComponent

# ── 引用 ──
var _boss: Boss3
var _player: Player
var _input_pkg: InputPackage
var _brain: BrainComponent

# ── 跳跃目标计算缓存 ──
var _has_pending_jump: bool = false

func initialize(boss: Boss3, brain: BrainComponent, input_pkg: InputPackage) -> void:
	_boss = boss
	_player = boss.player_ref
	_brain = brain
	_input_pkg = input_pkg

# ════════════════════════════════════════════
# process() — 在 _process() 中调用，处理动作状态切换
# ════════════════════════════════════════════
func process(_delta: float) -> void:
	if not _boss or _boss.is_dead or not _player:
		return

	if not _is_state_interruptible():
		return

	# 按优先级处理（高 → 低）
	if _try_special_move(): return
	if _try_flight(): return
	if _try_sword_skill(): return
	if _try_ninjutsu(): return
	if _try_throw(): return

	# 先处理下蹲状态（为下蹲攻击做准备）
	_handle_crouch()
	if _try_basic_action(): return

	# 移动状态动画：RunState ↔ IdleState
	_sync_movement_animation()


# ════════════════════════════════════════════
# physics() — 在 _physics_process() 中调用，处理物理
# ════════════════════════════════════════════
func physics(delta: float) -> void:
	if not _boss or _boss.is_dead:
		return

	# 1. 统一处理重力（所有状态，除非 ignore_gravity）
	_apply_gravity(delta)

	# 2. 移动和面向玩家（仅在可中断状态下）
	if _is_state_interruptible():
		_apply_movement(delta)
		_face_player()


# ════════════════════════════════════════════
# 优先级 0: 必杀技（最高优先级，独占）
# ════════════════════════════════════════════
func _try_special_move() -> bool:
	if _input_pkg.special_move:
		_boss.state_machine.change_state_by_name("Boss3SpecialMoveState")
		return true
	return false


# ════════════════════════════════════════════
# 优先级 1: 特殊飞行（独占，打断一切）
# ════════════════════════════════════════════
func _try_flight() -> bool:
	if _input_pkg.fly_to_top:
		_boss.state_machine.change_state_by_name("Boss3FlightToTopState")
		return true
	if _input_pkg.fly_to_left or _input_pkg.fly_to_right:
		_boss.state_machine.change_state_by_name("Boss3FallAirState")
		return true
	return false


# ════════════════════════════════════════════
# 优先级 2: 剑术
# ════════════════════════════════════════════
func _try_sword_skill() -> bool:
	if _input_pkg.sword_dash and _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3SwordDashState")
		return true
	if _input_pkg.sword_spin and _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3SwordSpinState")
		return true
	if _input_pkg.sword_uppercut and _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3SwordUppercutState")
		return true
	if _input_pkg.sword_downslash and not _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3SwordDownslashState")
		return true
	return false


# ════════════════════════════════════════════
# 优先级 3: 忍术
# ════════════════════════════════════════════
func _try_ninjutsu() -> bool:
	# 检测 4 种忍术按键
	var ninja_type = -1
	if _input_pkg.ninjutsu_fire:
		ninja_type = 0
	elif _input_pkg.ninjutsu_fireball:
		ninja_type = 1
	elif _input_pkg.ninjutsu_boomerang:
		ninja_type = 2
	elif _input_pkg.ninjutsu_edge_blade:
		ninja_type = 3

	if ninja_type >= 0:
		if _boss.is_on_floor():
			_boss.state_machine.change_state_by_name("Boss3GroundNinjutsuState", {"ninjutsu_type": ninja_type})
		else:
			_boss.state_machine.change_state_by_name("Boss3AirNinjutsuState", {"ninjutsu_type": ninja_type})
		return true
	return false


# ════════════════════════════════════════════
# 优先级 3.5: 投掷飞镖（远程消耗）
# ════════════════════════════════════════════
func _try_throw() -> bool:
	if _input_pkg.throw_dart and _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3ThrowState")
		return true
	return false


# ════════════════════════════════════════════
# 优先级 4: 基础动作（跳跃/攻击/格挡）
# ════════════════════════════════════════════
func _try_basic_action() -> bool:
	# 跳跃
	if _input_pkg.jump and _boss.is_on_floor():
		# 计算跳跃目标位置
		_calculate_jump_target()
		# 执行跳跃
		_boss.velocity.y = _boss.data.jump_velocity
		# 玩家不在空中时，禁止自动接空中攻击
		var player_on_floor = _player and _player.is_on_floor()
		# 如果 Brain 同时设置了火球，跳跃最高点释放
		var msg = {"air_attack": not player_on_floor}
		if _input_pkg.ninjutsu_fireball:
			msg["fireball"] = true
		_boss.state_machine.change_state_by_name("Boss3JumpState", msg)
		# 水平速度由 HandsComponent.physics() 在跳跃期间持续控制
		_has_pending_jump = false
		return true

	# 攻击
	if _input_pkg.attack:
		if _boss.is_on_floor():
			var cur = _boss.state_machine.current_state
			if cur is Boss3CrouchState:
				_boss.state_machine.change_state_by_name("Boss3CrouchAttackState")
			else:
				_boss.state_machine.change_state_by_name("Boss3AttackState")
		else:
			_boss.state_machine.change_state_by_name("Boss3AirAttackState")
		return true

	# 格挡：进入格挡状态（音效+火花由状态机自动播放）
	if _input_pkg.block and _boss.is_on_floor():
		_boss.state_machine.change_state_by_name("Boss3BlockState")
		return true

	return false


# ════════════════════════════════════════════
# 物理：重力
# ════════════════════════════════════════════
func _apply_gravity(delta: float) -> void:
	if not _boss.is_on_floor() and not _boss.ignore_gravity:
		_boss.velocity.y += _boss.data.gravity * delta


# ════════════════════════════════════════════
# 物理：移动（带加减速平滑过渡）
# ════════════════════════════════════════════
## 加速/减速度（像素/秒²），值越大响应越快
const MOVEMENT_ACCELERATION: float = 600.0

func _apply_movement(delta: float) -> void:
	# 固定速度 120（不随策略改变数值）
	var speed = _boss.data.run_speed

	# 计算目标速度
	var target_vx: float = 0.0
	match _input_pkg.move_x:
		1:  target_vx = speed
		0:  target_vx = 0.0
		-1: target_vx = -speed

	# 平滑过渡到目标速度（加减速），消除鬼畜感
	_boss.velocity.x = move_toward(_boss.velocity.x, target_vx, MOVEMENT_ACCELERATION * delta)

	# 撞墙冻结：一旦撞墙，0.25 秒内不再推墙
	# EVASIVE 墙角被困时，如果 move_x 朝向玩家（意欲脱离墙角），不锁定
	if _boss.wall_stuck_frames > 0:
		var is_escaping = _brain.current_strategy == BrainComponent.Strategy.EVASIVE and \
			_input_pkg.move_x == int(sign(_get_direction_to_player()))
		if not is_escaping:
			_boss.velocity.x = 0.0

	# 如果正在跳跃中，但 brain 没有设 move_x，维持跳跃时的水平速度
	# velocity.x 已经在 _calculate_jump_target() 中设置好了


# ════════════════════════════════════════════
# 跳跃目标计算
# ════════════════════════════════════════════
func _calculate_jump_target() -> void:
	if not _player:
		return

	var target_x = _player.global_position.x

	# 根据策略调整跳跃落点
	match _brain.current_strategy:
		BrainComponent.Strategy.OFFENSIVE:
			# 跳到玩家头顶或身后
			target_x += randf_range(-30.0, 30.0)
		BrainComponent.Strategy.DEFENSIVE:
			# 向后跳拉开距离
			target_x = _boss.global_position.x - sign(_get_direction_to_player()) * 80.0
		BrainComponent.Strategy.RANGED:
			# 跳向高处（保持距离）
			target_x = _player.global_position.x + randf_range(-20.0, 20.0)
		BrainComponent.Strategy.EVASIVE:
			# 向后跳远离玩家（和 DEFENSIVE 相同，但跳跃频率更高）
			target_x = _boss.global_position.x - sign(_get_direction_to_player()) * 80.0

	# 计算水平速度，让 Boss 跳到目标点
	var dx = target_x - _boss.global_position.x
	var jump_time = 2.0 * abs(_boss.data.jump_velocity) / _boss.data.gravity if _boss.data.gravity > 0 else 0.5
	var jump_vx = dx / jump_time if jump_time > 0 else 0.0

	# 限制最大水平速度不超过 run_speed 的 2 倍
	var max_speed = _boss.data.run_speed * 2.0
	jump_vx = clampf(jump_vx, -max_speed, max_speed)

	_boss.velocity.x = jump_vx
	_has_pending_jump = true


# ════════════════════════════════════════════
# 辅助方法
# ════════════════════════════════════════════

## 同步移动动画：IdleState ↔ RunState + CrouchState
func _sync_movement_animation() -> void:
	if not _boss.is_on_floor():
		return
	var cur = _boss.state_machine.current_state
	if cur is Boss3IdleState and abs(_boss.velocity.x) > 1.0:
		_boss.state_machine.change_state_by_name("Boss3RunState")
	elif cur is Boss3RunState and abs(_boss.velocity.x) <= 1.0:
		_boss.state_machine.change_state_by_name("Boss3IdleState")


## 处理下蹲状态：move_y=-1 时进入 CrouchState，松开时退出
func _handle_crouch() -> void:
	if not _boss.is_on_floor():
		return
	var cur = _boss.state_machine.current_state
	if _input_pkg.move_y == -1:
		if cur is Boss3IdleState or cur is Boss3RunState:
			_boss.state_machine.change_state_by_name("Boss3CrouchState")
	elif cur is Boss3CrouchState:
		_boss.state_machine.change_state_by_name("Boss3IdleState")


## 面向玩家（后退时面朝逃跑方向）
func _face_player() -> void:
	if not _player:
		return
	var dir = 1.0 if _player.global_position.x > _boss.global_position.x else -1.0

	# 主动远离玩家时（move_x 与朝向相反），面朝逃跑方向
	if _input_pkg.move_x != 0 and sign(_input_pkg.move_x) != sign(dir):
		dir = _input_pkg.move_x

	_boss.set_facing_direction(dir)


## 获取与玩家的水平距离
func _get_player_distance_x() -> float:
	if not _player:
		return 9999.0
	return abs(_player.global_position.x - _boss.global_position.x)


## 获取朝向玩家的方向（1=右，-1=左）
func _get_direction_to_player() -> float:
	if not _player:
		return 0.0
	return 1.0 if _player.global_position.x > _boss.global_position.x else -1.0


## 判断当前状态是否可中断（可以接收新输入）
func _is_state_interruptible() -> bool:
	var cur = _boss.state_machine.current_state
	return cur is Boss3IdleState or \
		   cur is Boss3RunState or \
		   cur is Boss3FallState
