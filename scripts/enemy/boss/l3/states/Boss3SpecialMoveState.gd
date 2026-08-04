# res://scripts/enemy/boss/l3/states/Boss3SpecialMoveState.gd
## 必杀技连段状态（11阶段连斩）
## 所有参数均由 BossData_3 数据驱动
extends Boss3State
class_name Boss3SpecialMoveState

# ── 阶段枚举 ──
enum Phase {
	FADE_OUT,       # fall_imbalance 淡出消失
	HIDDEN,         # 隐身 1s
	APPEAR,         # 在 Marker2D 以 charge 显现
	CHARGE_WAIT,    # 完全显现后等待 0.5s
	SP1_DASH,       # sp1 前冲
	SP1_HOLD,       # sp1 最后一帧 0.3s + 消失
	SP2_APPEAR,     # sp2 在玩家上角快速显现
	SP2_DIVE,       # sp2 下劈
	SP3_WAIT,       # sp3 落地等待 0.3s
	SP3_SPIN,       # sp3 旋转砍
	SP3_HOLD,       # sp3 最后一帧 0.3s + 消失
	SP4_APPEAR,     # sp4 在玩家左侧/右侧 80px 显现
	SP4_SLASH,      # sp4 挥刀前进 60px
	SP4_HOLD,       # sp4 最后一帧 0.3s + 消失
	SP5_APPEAR,     # sp5 在玩家另一侧 100px 显现
	SP5_SPIN,       # sp5 旋转前进 80px
	SP6_UPPERCUT,   # sp6 升龙击
	SP7_FLOAT,      # sp7 空中悬浮 0.5s
	SP7_DIVE,       # sp7 下劈
	SP7_LAND,       # sp7 落地维持 1s
	FINISHED
}

var _phase: int = Phase.FADE_OUT
var _phase_timer: float = 0.0
var _alpha_timer: float = 0.0

## BOSS 当前站在玩家哪一侧（1=右侧, -1=左侧），用于轮流切换攻击方位
var _side: int = 1

## 下劈方向锁定（sp2 / sp7 用）
var _dive_dir: Vector2

## 突进剩余距离（sp3/sp4/sp5/sp6 用）
var _dash_left: float = 0.0

## 地形墙壁碰撞层（layer 3），下劈穿透时移除
const WALL_COLLISION_LAYER: int = 8

var _fade_tween: Tween

## 下劈前保存的碰撞掩码（穿透恢复用）
var _saved_collision_mask: int = 0


func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true
	boss.animated_sprite.play("fall_imbalance")
	boss.hurt_box.set_deferred("monitoring", false)
	boss.hurt_box.set_deferred("monitorable", false)
	# 关闭所有攻击框，防止 FADE_OUT 阶段玩家碰触受伤
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.crouch_hit_box.set_deferred("monitoring", false)

	_phase = Phase.FADE_OUT
	_phase_timer = boss.data.special_fade_out_time
	_alpha_timer = 0.0
	_side = 1  # 初始右侧，后续根据 Marker2D 位置修正


func update(delta: float) -> void:
	_phase_timer -= delta
	_alpha_timer += delta

	match _phase:
		Phase.FADE_OUT:        _update_fade_out(delta)
		Phase.HIDDEN:          _update_hidden(delta)
		Phase.APPEAR:          _update_appear(delta)
		Phase.CHARGE_WAIT:     _update_charge_wait(delta)
		Phase.SP1_DASH:        _update_sp1_dash(delta)
		Phase.SP1_HOLD:        _update_sp1_hold(delta)
		Phase.SP2_APPEAR:      _update_sp2_appear(delta)
		Phase.SP2_DIVE:        _update_sp2_dive(delta)
		Phase.SP3_WAIT:        _update_sp3_wait(delta)
		Phase.SP3_SPIN:        _update_sp3_spin(delta)
		Phase.SP3_HOLD:        _update_sp3_hold(delta)
		Phase.SP4_APPEAR:      _update_sp4_appear(delta)
		Phase.SP4_SLASH:       _update_sp4_slash(delta)
		Phase.SP4_HOLD:        _update_sp4_hold(delta)
		Phase.SP5_APPEAR:      _update_sp5_appear(delta)
		Phase.SP5_SPIN:        _update_sp5_spin(delta)
		Phase.SP6_UPPERCUT:    _update_sp6_uppercut(delta)
		Phase.SP7_FLOAT:       _update_sp7_float(delta)
		Phase.SP7_DIVE:        _update_sp7_dive(delta)
		Phase.SP7_LAND:        _update_sp7_land(delta)


func physics_update(_delta: float) -> void:
	# sp2/sp7 下劈阶段：穿透地形，仅地面阻挡
	if _phase == Phase.SP2_DIVE:
		boss.velocity = _dive_dir * boss.data.sp2_dive_speed
		boss.ignore_gravity = true
		if boss.is_on_floor():
			_enter_sp3_wait()
		elif boss.velocity.y <= 0.0:
			# 下劈方向水平或朝上（玩家不在下方）→ 改为直接向下劈，
			# 避免下劈穿透地形时穿顶卡在墙壁/空中
			_dive_dir = Vector2(0, 1)
	elif _phase == Phase.SP7_DIVE:
		boss.velocity = _dive_dir * boss.data.sp7_dive_speed
		boss.ignore_gravity = true
		if boss.is_on_floor():
			_enter_sp7_land()
		elif boss.velocity.y <= 0.0:
			# 最后一击水平飞行或飞向天空 → 改为直接向下落，
			# 避免穿透地形穿顶后一直浮空卡在墙壁
			_dive_dir = Vector2(0, 1)


# ═══════════════════════════════════════════════
# 阶段 0: FADE_OUT - fall_imbalance 淡出消失
# ═══════════════════════════════════════════════
func _update_fade_out(_delta: float) -> void:
	boss.animated_sprite.play("fall_imbalance")
	var t = clampf(_alpha_timer / boss.data.special_fade_out_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = 1.0 - t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 0.0
		_enter_hidden()

func _enter_hidden() -> void:
	_phase = Phase.HIDDEN
	_phase_timer = boss.data.special_hidden_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.modulate.a = 0.0


# ═══════════════════════════════════════════════
# 阶段 1: HIDDEN - 隐身等待
# ═══════════════════════════════════════════════
func _update_hidden(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_enter_appear()

func _enter_appear() -> void:
	_phase = Phase.APPEAR
	_phase_timer = boss.data.special_appear_time
	_alpha_timer = 0.0

	# 随机选择 Marker2DLeft 或 Marker2DRight
	var boss_marker = get_tree().current_scene.get_node_or_null("BossMarker2D")
	var marker: Marker2D = null
	if boss_marker and boss_marker.get_child_count() >= 2:
		var left = boss_marker.get_node("Marker2DLeft") as Marker2D
		var right = boss_marker.get_node("Marker2DRight") as Marker2D
		if left and right:
			marker = left if randi() % 2 == 0 else right
			_side = -1 if marker == left else 1

	if marker:
		boss.global_position = marker.global_position
		# 面朝玩家：在右侧→面左，在左侧→面右
		boss.set_facing_direction(-1.0 if _side == 1 else 1.0)
	else:
		# 没有标记点保住当前 X，Y 对齐玩家
		if boss.player_ref:
			boss.global_position = Vector2(boss.global_position.x, boss.player_ref.global_position.y)
		_side = 1
	_clamp_position_to_room()

	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true
	boss.animated_sprite.modulate.a = 0.0
	boss.animated_sprite.play("charge")


# ═══════════════════════════════════════════════
# 阶段 2: APPEAR - 以 charge 动画显现
# ═══════════════════════════════════════════════
func _update_appear(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.special_appear_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 1.0
		_enter_charge_wait()

func _enter_charge_wait() -> void:
	_phase = Phase.CHARGE_WAIT
	_phase_timer = boss.data.special_charge_wait
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true


# ═══════════════════════════════════════════════
# 阶段 3: CHARGE_WAIT - 充能完成等待
# ═══════════════════════════════════════════════
func _update_charge_wait(_delta: float) -> void:
	if _phase_timer <= 0.0:
		boss.hurt_box.set_deferred("monitoring", true)
		boss.hurt_box.set_deferred("monitorable", true)
		_enter_sp1_dash()


# ═══════════════════════════════════════════════
# 阶段 4: SP1_DASH - sp1 朝玩家前冲
# ═══════════════════════════════════════════════
func _enter_sp1_dash() -> void:
	_phase = Phase.SP1_DASH
	_phase_timer = 2.0  # 安全超时

	boss.animated_sprite.play("sp1")
	boss.animated_sprite.modulate.a = 1.0
	boss.ignore_gravity = true
	boss.sword_hit_box.set_deferred("monitoring", true)

	if boss.player_ref:
		var dir = sign(boss.player_ref.global_position.x - boss.global_position.x)
		boss.set_facing_direction(dir)
	boss.velocity.x = boss.facing_direction * boss.data.sp1_dash_speed
	_play_sfx_at_frame(&"jianqianchong", 1)

func _update_sp1_dash(_delta: float) -> void:
	# 动画播放完毕或撞墙 → 进入 hold
	if boss.is_on_wall() or not boss.animated_sprite.is_playing():
		_enter_sp1_hold()
	# 安全超时
	if _phase_timer <= 0.0:
		_enter_sp1_hold()

func _enter_sp1_hold() -> void:
	_phase = Phase.SP1_HOLD
	_phase_timer = boss.data.sp1_hold_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.ignore_gravity = true
	# 锁定在 sp1 最后一帧（暂停动画）
	boss.animated_sprite.pause()


# ═══════════════════════════════════════════════
# 阶段 5: SP1_HOLD - 维持最后一帧 + 淡出消失
# ═══════════════════════════════════════════════
func _update_sp1_hold(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp1_hold_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = 1.0 - t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 0.0
		boss.hurt_box.set_deferred("monitoring", false)
		boss.hurt_box.set_deferred("monitorable", false)
		boss.animated_sprite.play("sp1")  # 恢复动画（alpha=0 不可见）
		_enter_sp2_appear()


# ═══════════════════════════════════════════════
# 阶段 6: SP2_APPEAR - 在玩家上角快速显现
# ═══════════════════════════════════════════════
func _enter_sp2_appear() -> void:
	_phase = Phase.SP2_APPEAR
	_phase_timer = boss.data.sp2_appear_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true

	# 换到玩家另一侧的上角
	_side = -_side
	var offset_x = _side * 60.0  # 水平偏移
	if boss.player_ref:
		var px = boss.player_ref.global_position.x + offset_x
		var py = boss.player_ref.global_position.y - 120.0  # 上角
		boss.global_position = Vector2(px, py)
		boss.set_facing_direction(-_side)  # 面向玩家
	_clamp_position_to_room()

	boss.animated_sprite.modulate.a = 0.0
	boss.animated_sprite.play("sp2")

func _update_sp2_appear(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp2_appear_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 1.0
		_enter_sp2_dive()

func _enter_sp2_dive() -> void:
	_phase = Phase.SP2_DIVE
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.ignore_gravity = true
	# 锁定下劈方向（朝玩家位置）
	if boss.player_ref:
		var target = boss.player_ref.global_position
		if abs(target.x - boss.global_position.x) < 40.0:
			target.x += 40.0 * boss.facing_direction
		_dive_dir = (target - boss.global_position).normalized()
	else:
		_dive_dir = Vector2(boss.facing_direction, 1).normalized()
	boss.velocity = _dive_dir * boss.data.sp2_dive_speed
	# sp2 下劈穿透地形
	_enable_wall_penetration()
	_play_sfx_at_frame(&"jianxiapi", 1)

func _update_sp2_dive(_delta: float) -> void:
	pass  # 落地检测在 physics_update 中


# ═══════════════════════════════════════════════
# 阶段 8: SP3_WAIT - 落地等待 0.3s
# ═══════════════════════════════════════════════
func _enter_sp3_wait() -> void:
	_phase = Phase.SP3_WAIT
	_phase_timer = boss.data.sp3_land_wait
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.ignore_gravity = false
	_disable_wall_penetration()

func _update_sp3_wait(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_enter_sp3_spin()


# ═══════════════════════════════════════════════
# 阶段 9: SP3_SPIN - sp3 旋转砍
# ═══════════════════════════════════════════════
func _enter_sp3_spin() -> void:
	_phase = Phase.SP3_SPIN
	_phase_timer = 2.0
	boss.animated_sprite.play("sp3")
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.ignore_gravity = true
	if boss.player_ref:
		var dir = sign(boss.player_ref.global_position.x - boss.global_position.x)
		boss.set_facing_direction(dir)
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * 1.5
	_dash_left = boss.data.sp3_spin_distance
	_play_sfx_at_frame(&"gongji", 2)

func _update_sp3_spin(delta: float) -> void:
	if boss.is_on_wall():
		boss.velocity.x = 0.0
		_enter_sp3_hold()
		return
	if _dash_left > 0.0:
		_dash_left -= abs(boss.velocity.x * delta)
		if _dash_left <= 0.0:
			boss.velocity.x = 0.0
			_enter_sp3_hold()


# ═══════════════════════════════════════════════
# 阶段 10: SP3_HOLD - 最后一帧 + 消失
# ═══════════════════════════════════════════════
func _enter_sp3_hold() -> void:
	_phase = Phase.SP3_HOLD
	_phase_timer = boss.data.sp3_hold_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.animated_sprite.pause()

func _update_sp3_hold(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp3_hold_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = 1.0 - t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 0.0
		boss.hurt_box.set_deferred("monitoring", false)
		boss.hurt_box.set_deferred("monitorable", false)
		boss.animated_sprite.play("sp3")
		_enter_sp4_appear()


# ═══════════════════════════════════════════════
# 阶段 11: SP4_APPEAR - 玩家另一侧 80px 显现
# ═══════════════════════════════════════════════
func _enter_sp4_appear() -> void:
	_phase = Phase.SP4_APPEAR
	_phase_timer = boss.data.sp4_appear_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true

	_side = -_side
	if boss.player_ref:
		var px = boss.player_ref.global_position.x + _side * boss.data.sp4_appear_distance
		boss.global_position = Vector2(px, boss.player_ref.global_position.y)
		boss.set_facing_direction(-_side)
	_clamp_position_to_room()

	boss.animated_sprite.modulate.a = 0.0
	boss.animated_sprite.play("sp4")

func _update_sp4_appear(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp4_appear_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 1.0
		_enter_sp4_slash()


# ═══════════════════════════════════════════════
# 阶段 12: SP4_SLASH - 挥刀突进 60px
# ═══════════════════════════════════════════════
func _enter_sp4_slash() -> void:
	_phase = Phase.SP4_SLASH
	_phase_timer = 2.0
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.ignore_gravity = true
	boss.velocity.x = boss.facing_direction * boss.data.sp4_slash_speed
	_dash_left = boss.data.sp4_slash_distance
	_play_sfx_at_frame(&"gongji", 1)

func _update_sp4_slash(delta: float) -> void:
	if boss.is_on_wall():
		boss.velocity.x = 0.0
		_enter_sp4_hold()
		return
	if _dash_left > 0.0:
		_dash_left -= abs(boss.velocity.x * delta)
		if _dash_left <= 0.0:
			boss.velocity.x = 0.0
			_enter_sp4_hold()


# ═══════════════════════════════════════════════
# 阶段 13: SP4_HOLD - 最后一帧 + 消失
# ═══════════════════════════════════════════════
func _enter_sp4_hold() -> void:
	_phase = Phase.SP4_HOLD
	_phase_timer = boss.data.sp4_hold_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.animated_sprite.pause()

func _update_sp4_hold(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp4_hold_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = 1.0 - t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 0.0
		boss.hurt_box.set_deferred("monitoring", false)
		boss.hurt_box.set_deferred("monitorable", false)
		boss.animated_sprite.play("sp4")
		_enter_sp5_appear()


# ═══════════════════════════════════════════════
# 阶段 14: SP5_APPEAR - 玩家另一侧 100px 显现
# ═══════════════════════════════════════════════
func _enter_sp5_appear() -> void:
	_phase = Phase.SP5_APPEAR
	_phase_timer = boss.data.sp5_appear_time
	_alpha_timer = 0.0
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true

	_side = -_side
	if boss.player_ref:
		var px = boss.player_ref.global_position.x + _side * boss.data.sp5_appear_distance
		boss.global_position = Vector2(px, boss.player_ref.global_position.y)
		boss.set_facing_direction(-_side)
	_clamp_position_to_room()

	boss.animated_sprite.modulate.a = 0.0
	boss.animated_sprite.play("sp5")

func _update_sp5_appear(_delta: float) -> void:
	var t = clampf(_alpha_timer / boss.data.sp5_appear_time, 0.0, 1.0)
	boss.animated_sprite.modulate.a = t
	if _phase_timer <= 0.0:
		boss.animated_sprite.modulate.a = 1.0
		_enter_sp5_spin()


# ═══════════════════════════════════════════════
# 阶段 15: SP5_SPIN - 旋转前进 80px
# ═══════════════════════════════════════════════
func _enter_sp5_spin() -> void:
	_phase = Phase.SP5_SPIN
	_phase_timer = 2.0
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.ignore_gravity = true
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * 1.5
	_dash_left = boss.data.sp5_spin_distance
	_play_sfx_at_frame(&"jianxuanzhuan", 1)

func _update_sp5_spin(delta: float) -> void:
	if boss.is_on_wall():
		boss.velocity.x = 0.0
		_enter_sp6_uppercut()
		return
	if _dash_left > 0.0:
		_dash_left -= abs(boss.velocity.x * delta)
		if _dash_left <= 0.0:
			boss.velocity.x = 0.0
			_enter_sp6_uppercut()


# ═══════════════════════════════════════════════
# 阶段 16: SP6_UPPERCUT - 升龙击
# ═══════════════════════════════════════════════
func _enter_sp6_uppercut() -> void:
	_phase = Phase.SP6_UPPERCUT
	boss.animated_sprite.play("sp6")
	boss.velocity.y = boss.data.jump_velocity * boss.data.uppercut_jump_multiplier
	boss.velocity.x = boss.facing_direction * boss.data.run_speed * boss.data.uppercut_speed_multiplier
	_dash_left = boss.data.sp6_uppercut_distance
	boss.ignore_gravity = false
	_play_sfx_at_frame(&"jianshangtiao", 0)

func _update_sp6_uppercut(delta: float) -> void:
	if boss.is_on_wall():
		boss.velocity.x = 0.0
		_dash_left = 0.0
	if _dash_left > 0.0:
		_dash_left -= abs(boss.velocity.x * delta)
		if _dash_left <= 0.0:
			boss.velocity.x = 0.0
	if boss.velocity.y > 0:
		# 达到最高点→进入 SP7 悬浮
		boss.sword_hit_box.set_deferred("monitoring", false)
		_enter_sp7_float()


# ═══════════════════════════════════════════════
# 阶段 17: SP7_FLOAT - 空中悬浮 0.5s
# ═══════════════════════════════════════════════
func _enter_sp7_float() -> void:
	_phase = Phase.SP7_FLOAT
	_phase_timer = boss.data.sp7_float_time
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = true
	boss.animated_sprite.play("sp7")
	boss.animated_sprite.modulate.a = 1.0
	# 面向玩家
	if boss.player_ref:
		boss.set_facing_direction(
			1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		)

func _update_sp7_float(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_enter_sp7_dive()


# ═══════════════════════════════════════════════
# 阶段 18: SP7_DIVE - 下劈
# ═══════════════════════════════════════════════
func _enter_sp7_dive() -> void:
	_phase = Phase.SP7_DIVE
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.ignore_gravity = true
	# 朝玩家下劈
	if boss.player_ref:
		var target = boss.player_ref.global_position
		if abs(target.x - boss.global_position.x) < 40.0:
			target.x += 40.0 * boss.facing_direction
		_dive_dir = (target - boss.global_position).normalized()
	else:
		_dive_dir = Vector2(boss.facing_direction, 1).normalized()
	boss.velocity = _dive_dir * boss.data.sp7_dive_speed
	# sp7 下劈穿透地形
	_enable_wall_penetration()
	_play_sfx_at_frame(&"jianqianchong", 1)

func _update_sp7_dive(_delta: float) -> void:
	pass  # 落地检测在 physics_update 中


# ═══════════════════════════════════════════════
# 阶段 19: SP7_LAND - 落地维持 1s
# ═══════════════════════════════════════════════
func _enter_sp7_land() -> void:
	_phase = Phase.SP7_LAND
	_phase_timer = boss.data.sp7_land_hold
	boss.velocity = Vector2.ZERO
	boss.sword_hit_box.set_deferred("monitoring", false)
	boss.ignore_gravity = false
	_disable_wall_penetration()
	# 锁定 sp7 最后一帧
	boss.animated_sprite.pause()

func _update_sp7_land(_delta: float) -> void:
	if _phase_timer <= 0.0:
		_finish_special_move()


# ═══════════════════════════════════════════════
# 结束
# ═══════════════════════════════════════════════
func _finish_special_move() -> void:
	_phase = Phase.FINISHED
	boss.animated_sprite.modulate.a = 1.0
	boss.animated_sprite.play()
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = false
	_disable_wall_penetration()
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.crouch_hit_box.set_deferred("monitoring", true)
	state_machine.change_state_by_name("Boss3IdleState")


func exit() -> void:
	super()
	_cleanup_tween()
	boss.animated_sprite.modulate.a = 1.0
	if boss.animated_sprite.is_playing() == false:
		boss.animated_sprite.play()
	boss.velocity = Vector2.ZERO
	boss.ignore_gravity = false
	_disable_wall_penetration()
	boss.hurt_box.set_deferred("monitoring", true)
	boss.hurt_box.set_deferred("monitorable", true)
	# 恢复所有攻击框
	boss.sword_hit_box.set_deferred("monitoring", true)
	boss.crouch_hit_box.set_deferred("monitoring", true)

func _cleanup_tween() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
		_fade_tween = null


# ═══════════════════════════════════════════════
# 音效及穿透辅助
# ═══════════════════════════════════════════════

## 在指定动画帧播放斩击音效
func _play_sfx_at_frame(sfx_name: StringName, frame_idx: int) -> void:
	var speed: float = 15.0
	if boss.animated_sprite.sprite_frames:
		speed = boss.animated_sprite.sprite_frames.get_animation_speed(
			boss.animated_sprite.animation
		)
	if speed <= 0.0:
		speed = 15.0
	var delay: float = frame_idx * (1.0 / speed)
	get_tree().create_timer(delay).timeout.connect(func():
		AudioManager.play_sound(sfx_name)
	)

## 开启墙壁穿透（移除墙壁碰撞层）
func _enable_wall_penetration() -> void:
	_saved_collision_mask = boss.collision_mask
	boss.collision_mask = boss.collision_mask & ~WALL_COLLISION_LAYER

## 恢复墙壁碰撞
func _disable_wall_penetration() -> void:
	boss.collision_mask = _saved_collision_mask


# ═══════════════════════════════════════════════
# 房间边界
# ═══════════════════════════════════════════════

const ROOM_LEFT_X: float = 565.0
const ROOM_RIGHT_X: float = 980.0

## 将 Boss X 坐标限制在房间边界内，防止瞬移出墙
func _clamp_position_to_room() -> void:
	boss.global_position.x = clampf(boss.global_position.x, ROOM_LEFT_X, ROOM_RIGHT_X)
