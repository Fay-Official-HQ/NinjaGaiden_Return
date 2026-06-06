extends State
class_name DragonFlashState

# ====== 时间常量（单位：秒）======
const FADE_IN_TIME = 0.5      # 阶段0：角色渐隐消失耗时
const FADE_OUT_TIME = 0.25     # 阶段2：角色渐显恢复耗时
const SKILL_DURATION = 2.0    # 阶段1：技能持续总时长（斩击波阶段）
const WAVE_INTERVAL = 0.15    # 每波斩击的时间间隔

# ====== 残影参数 ======
const SHADOWS_PER_WAVE = 3    # 每波生成的残影数量
const SHADOW_ACTIVE = 0.15    # 每个残影保持可见的时间
const SHADOW_FADE = 0.05       # 残影淡出消失的过渡时间

# ====== 残影扩散范围（像素）======
const SPREAD_X = 120.0        # 残影在X轴随机偏移的最大范围
const SPREAD_Y = 50.0         # 残影在Y轴随机偏移的最大范围

# ====== 移动参数 ======
const SPEED_MULTIPLIER = 0.35  # 技能期间移动速度倍率（0.5 = 半速）
const PLAYER_ALPHA = 0.0      # 技能期间玩家透明度（0.0 = 完全透明）

# 5种残影贴图，每波随机选取
var shadow_textures = [
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_1.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_2.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_3.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_4.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_5.png")
]

# getter 属性：延迟获取子节点引用，避免 _ready 顺序问题
var sprite: AnimatedSprite2D:
	get: return player.get_node("Visual/AnimatedSprite2D")
var shadow_container: Node2D:
	get: return player.get_node("ShadowContainer")

# ====== 状态机变量 ======
var _state = 0                # 当前阶段：0=淡入/1=斩击/2=淡出
var _timer = 0.0              # 当前阶段的计时器
var _wave_timer = 0.0         # 斩击波间隔计时器
var _wave_count = 0           # 已生成的斩击波数（用于控制闪屏频率）
var _tween_fade: Tween = null # 透明度渐变的 Tween 引用
var _dragon_hit_box: DragonFlashHitBox  # AOE伤害框引用

func enter(_msg: Dictionary = {}) -> void:
	if player.sword.is_on_cooldown("finish"):
		print("【必杀技】冷却中，剩余:", player.sword.get_cooldown_remaining("finish"), "秒")
		if player.is_on_floor():
			state_machine.change_state(player.idle_state)
		else:
			state_machine.change_state(player.fall_state, {"imbalance": false})
		return

	# 初始化所有状态变量
	_state = 0
	_timer = 0.0
	_wave_timer = 0.0

	# 触发必杀技冷却
	player.sword.start_cooldown("finish")

	# 开启无敌 + 禁用重力（角色悬浮空中）
	player.is_invincible = true
	player.is_gravity_disabled = true

	# 消灭可能残留的上一次 Tween
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	# Tween：角色逐渐透明消失
	_tween_fade = create_tween()
	_tween_fade.tween_property(sprite, "modulate:a", PLAYER_ALPHA, FADE_IN_TIME)

	# 获取场景中的 DragonFlashHitBox，开启它的碰撞监控（发射伤害雷达）
	var box_node = player.get_node("AttackRoot/DragonFlashHitBox")
	if box_node:
		_dragon_hit_box = box_node as DragonFlashHitBox
		_dragon_hit_box.set_deferred("monitoring", true)

func update(_delta: float) -> void:
	# 三段式状态机：0(淡入) → 1(斩击波) → 2(淡出)
	match _state:
		0:
			# 阶段0：角色透明化淡入，持续 FADE_IN_TIME 秒
			_timer += _delta
			if _timer >= FADE_IN_TIME:
				_state = 1          # 进入斩击阶段
				_timer = 0.0
			# 阶段0期间也重置波次计数器，确保进入阶段1时波次从干净状态开始
			_wave_timer = WAVE_INTERVAL
			_wave_count = 0

		1:
			# 阶段1：核心输出阶段，每隔 WAVE_INTERVAL 秒生成一波残影
			_timer += _delta
			_wave_timer += _delta
			if _wave_timer >= WAVE_INTERVAL:
				_wave_timer -= WAVE_INTERVAL   # 保持累积不丢失，而非清零
				spawn_wave()

			# 技能持续时间结束后，进入淡出阶段
			if _timer >= SKILL_DURATION:
				_state = 2
				_timer = 0.0
				trigger_screen_flash()  # 最后一次斩击强制闪屏
				if _tween_fade and _tween_fade.is_valid():
					_tween_fade.kill()
				# Tween：角色逐渐恢复可见
				_tween_fade = create_tween()
				_tween_fade.tween_property(sprite, "modulate:a", 1.0, FADE_OUT_TIME)

		2:
			# 阶段2：等待淡出动画完成，然后退出技能
			_timer += _delta
			if _timer >= FADE_OUT_TIME:
				finish_skill()

func physics_update(_delta: float) -> void:
	# 强制悬浮：禁用Y轴速度（重力已被 is_gravity_disabled 禁用）
	player.velocity.y = 0

	# 水平移动：半速（SPEED_MULTIPLIER=0.5），可以左右微调位置
	var dir = player.input.move_direction
	player.velocity.x = dir * player.data.walk_speed * SPEED_MULTIPLIER
	if dir != 0:
		player.set_facing_direction(dir)

	player.move_and_slide()

func spawn_wave() -> void:
	# 每波生成 SHADOWS_PER_WAVE 个残影
	_wave_count += 1
	for i in range(SHADOWS_PER_WAVE):
		create_shadow()

	# 每3波触发一次全屏闪烁（同时也是 AOE 伤害触发时机）
	# 最后一次斩击的闪烁由 update() 阶段1→阶段2过渡时强制触发
	if _wave_count % 3 == 0:
		trigger_screen_flash()

func create_shadow() -> void:
	# 从5种残影贴图中随机选一个
	var tex = shadow_textures[randi() % shadow_textures.size()]

	var s = Sprite2D.new()
	s.texture = tex
	s.modulate.a = randf_range(0.4, 0.7)    # 随机半透明度
	s.scale.x = 1.0 if randf() > 0.5 else -1.0  # 随机左右翻转
	s.rotation = deg_to_rad(randf_range(-15, 15)) # 随机微旋转
	s.scale *= randf_range(0.9, 1.1)       # 随机微缩放

	shadow_container.add_child(s)

	# 残影出现在玩家周围随机位置，范围由 SPREAD_X/Y 控制
	s.global_position = player.global_position \
		+ Vector2(randf_range(-SPREAD_X, SPREAD_X), randf_range(-SPREAD_Y, SPREAD_Y))

	# Tween 生命周期：显示一段时间 → 淡出 → 自动销毁
	var tw = create_tween().set_parallel(false)
	tw.tween_interval(SHADOW_ACTIVE)          # 先保持可见
	tw.tween_property(s, "modulate:a", 0.0, SHADOW_FADE)  # 然后淡出
	tw.tween_callback(s.queue_free)            # 最后从场景树移除

func trigger_screen_flash() -> void:
	# 创建一个全屏白色 CanvasLayer（覆盖在所有内容之上）
	var canvas = CanvasLayer.new()
	canvas.layer = 100  # 极高层级确保在最上面
	player.get_tree().current_scene.add_child(canvas)

	# 全屏白色矩形
	var rect = ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡鼠标点击
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 铺满全屏
	canvas.add_child(rect)

	# Tween：白屏在 0.1 秒内淡出消失，然后自动销毁
	var tw = create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.1)
	tw.tween_callback(canvas.queue_free)

	# 闪屏的同时对范围内的敌人造成 AOE 伤害
	deal_aoe_damage()

func deal_aoe_damage() -> void:
	# 如果伤害框未就绪或未开启监控，直接跳过
	if not _dragon_hit_box or not _dragon_hit_box.monitoring:
		return

	# 扫描所有重叠的 Area2D
	var areas = _dragon_hit_box.get_overlapping_areas()
	for area in areas:
		# 只对 HurtBox 类型的节点造成伤害
		if area is HurtBox:
			area.take_damage(_dragon_hit_box.damage)

func finish_skill() -> void:
	# 清理所有残留残影
	for child in shadow_container.get_children():
		child.queue_free()

	# 关闭伤害框
	if _dragon_hit_box:
		_dragon_hit_box.set_deferred("monitoring", false)

	# 恢复玩家状态：取消无敌、恢复重力
	player.is_invincible = false
	player.is_gravity_disabled = false

	# 恢复角色可见
	sprite.modulate.a = 1.0

	# 回到下落状态（真龙闪华只能在空中释放）
	state_machine.change_state(player.fall_state, {"imbalance": false})

func exit() -> void:
	# 安全清理工具函数：当状态被外部强制切换时也能正确清理

	# 停止正在进行的透明度 Tween
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	# 清理所有残留残影
	for child in shadow_container.get_children():
		child.queue_free()

	# 关闭伤害框
	if _dragon_hit_box:
		_dragon_hit_box.set_deferred("monitoring", false)

	# 恢复玩家状态
	player.is_invincible = false
	player.is_gravity_disabled = false

	# 确保角色恢复可见
	if sprite:
		sprite.modulate.a = 1.0
