extends BossState
class_name Boss4AttackState

## ============================================================
## BOSS4 攻击状态（火焰聚集 → 能量波）
## 流程：
##  1. 在 Marker2D ~ Marker2D4 生成 4 团蓝色鬼火（boss_ghost_fire），
##     鬼火慢慢飞向 Marker2D5 聚集点
##  2. 等待本轮火焰全部结束（到达聚集点 / 被玩家消灭 / 飞出屏幕），
##     全部结束立即结算，无需等满超时（collect_wait_time 仅作防卡死兜底）
##  3. 有聚集时：显示能量动画 EnergyAnimated 闪烁 energy_flicker_duration 秒
##  4. 从 Marker2D5 朝玩家方向发射追踪能量波 EnergyFire
##     伤害 = 收集鬼火数 * per_fire_damage（每收集 1 个 +2，4 个全部收集 = 8）
##  5. 一个都没聚集则不发射能量波
##  6. 返回待机状态（攻击循环）
## ============================================================

## 蓝色鬼火场景（聚集火焰，由 BOSS 在 Marker2D~4 生成）
const FIRE_SCENE: PackedScene = preload("res://scenes/enemy/l4/boss_ghost_fire.tscn")
## 追踪能量波投射物场景
const ENERGY_FIRE_SCENE: PackedScene = preload("res://scenes/enemy/boss/l4/EnergyFire.tscn")
## 鬼火生成点名称（Marker2D ~ Marker2D4）
const MARKER_NAMES: Array[String] = ["Marker2D", "Marker2D2", "Marker2D3", "Marker2D4"]

## 已聚集的鬼火数量
var _collected: int = 0
## 本轮还在屏幕中的火焰（未到达、未被消灭）。全部结束后立即结算，无需等满超时
var _active_fires: Array[BossGhostFire] = []
## 蓄力能量期间的音效播放器（与玩家蓄力音效一致，发射后淡出停止）
var _charge_sfx: AudioStreamPlayer = null
## 攻击流程是否运行中（防止重复进入）
var _running: bool = false


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_run_attack()


func exit() -> void:
	# 状态退出时隐藏能量动画、停止蓄力音效，防止残留
	var energy = boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D
	if energy:
		energy.visible = false
		energy.modulate.a = 1.0
	_stop_charge_sfx()


func _run_attack() -> void:
	if _running or not is_inside_tree():
		return
	_running = true
	var data: BossData_4 = boss.data as BossData_4

	# 骷髅头播放攻击动画
	var head = boss.get_node_or_null("Visual/HeadAnimatedSprite2D") as AnimatedSprite2D
	if head and head.sprite_frames and head.sprite_frames.has_animation("attack"):
		head.play("attack")

	_collected = 0
	_active_fires.clear()

	# 1. 在 Marker2D ~ Marker2D4 生成鬼火，飞向 Marker2D5 聚集
	var fire_count: int = int(data.fire_count) if data else 4
	var m5 = boss.get_node_or_null("BossMark/Marker2D5") as Marker2D
	for i in range(fire_count):
		var marker = boss.get_node_or_null("BossMark/" + MARKER_NAMES[i]) as Marker2D
		if not marker or not m5:
			continue
		var fire: BossGhostFire = FIRE_SCENE.instantiate()
		fire.set_fly_speed(data.fire_speed if data else 80.0)
		fire.set_idle_time(data.fire_idle_time if data else 2.0)
		fire.reached_target.connect(_on_fire_reached)
		fire.finished.connect(_on_fire_finished)
		_active_fires.append(fire)
		get_tree().current_scene.add_child(fire)
		# 先进树再设置绝对位置，保证生成点准确
		fire.global_position = marker.global_position
		# 关键：传入聚集目标坐标（不传则鬼火不会飞向聚集点）
		fire.initialize(m5.global_position)

	# 每一波生成时播放音效（与普通鬼火生成器一致）
	AudioManager.play_sound(data.spawn_sound if data else &"guihuo")

	# 2. 等待本轮火焰全部结束（到达聚集点 / 被玩家消灭 / 飞出屏幕）
	#    屏幕中只要还有活着的火焰就继续等；全部结束立即结算，
	#    不再需要等满收集时间（collect_wait_time 仅作防卡死兜底）
	var wait_time: float = data.collect_wait_time if data else 8.0
	while is_inside_tree() and not _active_fires.is_empty() and wait_time > 0.0:
		if boss.is_dead:
			return
		await get_tree().physics_frame
		if not is_inside_tree():
			return
		wait_time -= get_physics_process_delta_time()

	# 3. 结算：一个都没聚集则不发射能量波
	if _collected > 0 and not boss.is_dead:
		await _do_energy_phase(_collected)

	_running = false
	if not is_inside_tree():
		return
	if not boss.is_dead:
		state_machine.change_state_by_name("BossIdleState")


## 鬼火到达聚集点（Marker2D5）时回调
func _on_fire_reached(fire: BossGhostFire) -> void:
	_collected += 1
	_active_fires.erase(fire)


## 鬼火结束时回调（到达 / 被消灭 / 飞出屏幕）：从活跃列表移除，
## 全部移除后等待循环立即退出并结算
func _on_fire_finished(fire: BossGhostFire) -> void:
	_active_fires.erase(fire)


## 能量阶段：显示能量动画闪烁 → 从 Marker2D5 朝玩家发射能量波
func _do_energy_phase(collected: int) -> void:
	var data: BossData_4 = boss.data as BossData_4
	var energy = boss.get_node_or_null("Visual/EnergyAnimated") as AnimatedSprite2D

	# 4. 显示能量动画并闪烁 energy_flicker_duration 秒，期间播放蓄力音效（与玩家一致）
	if energy:
		energy.visible = true
		_charge_sfx = AudioManager.play_sfx_fade_in(data.charge_sound if data else &"xuli", 0.0)
		var flicker: float = data.energy_flicker_duration if data else 2.0
		var min_alpha: float = data.flicker_min_alpha if data else 0.2
		var half_period: float = data.flicker_half_period if data else 0.125
		var tw: Tween = boss.create_tween()
		var steps: int = maxi(1, int(flicker / (half_period * 2.0)))
		for i in range(steps):
			tw.tween_property(energy, "modulate:a", min_alpha, half_period)
			tw.tween_property(energy, "modulate:a", 1.0, half_period)
		await boss.get_tree().create_timer(flicker).timeout
		if not is_inside_tree():
			_stop_charge_sfx()
			return
		energy.visible = false
		energy.modulate.a = 1.0

	if boss.is_dead:
		_stop_charge_sfx()
		return

	# 5. 从 Marker2D5 朝玩家方向发射追踪能量波
	var m5 = boss.get_node_or_null("BossMark/Marker2D5") as Marker2D
	if m5 and boss.player_ref:
		var energy_fire: EnergyFire = ENERGY_FIRE_SCENE.instantiate()
		var damage: int = collected * (data.per_fire_damage if data else 2)
		energy_fire.set_damage(damage)
		var dir: Vector2 = (boss.player_ref.global_position - m5.global_position).normalized()
		energy_fire.initialize(dir, data.energy_wave_speed if data else 300.0)
		# 先进树再设置绝对位置（与鬼火生成保持一致，未进树时 global_position 不可靠）
		get_tree().current_scene.add_child(energy_fire)
		energy_fire.global_position = m5.global_position

	# 能量波已发射，停止蓄力音效
	_stop_charge_sfx()


## 停止蓄力能量音效（淡出后停止）
func _stop_charge_sfx() -> void:
	if _charge_sfx:
		AudioManager.stop_sfx_fade_out(_charge_sfx, 0.3)
		_charge_sfx = null
