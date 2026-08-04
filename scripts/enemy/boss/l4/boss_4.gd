extends Boss
class_name Boss_4

## ============================================================
## 第四关 BOSS —— 建筑类（骷髅头 HeadAnimatedSprite2D + 女人身体 AnimatedSprite2D）
## 特点：
##  1. 固定不动：产生后一直锁定在坐标位置，不受物理推挤
##  2. 女人身体动画由场景 autoplay 自动播放；骷髅头动画由代码控制
##  3. 受伤无剑术重伤特效，任意伤害只对骷髅头（HeadAnimatedSprite2D）短暂闪白
##  4. 死亡时关闭骷髅头受伤框 + 身体全部攻击碰撞框（AttackRoot/EnemyHitBox 下 11 个形状）+ 底座碰撞
##  5. 死亡交给 BossDeathDirector（红黑剪影流程，骷髅头和女人身体同时显示剪影）
## ============================================================

## 骷髅头动画节点（受伤闪白/攻击动画都控制它）
@onready var head_animated: AnimatedSprite2D = $Visual/HeadAnimatedSprite2D
## 能量动画节点（聚集完成后的闪烁）
@onready var energy_animated: AnimatedSprite2D = $Visual/EnergyAnimated

## 小怪（hopper_monster）场景
const HOPPER_SCENE: PackedScene = preload("res://scenes/enemy/l4/hopper_monster.tscn")

## 建筑生成后的固定坐标（锁定位置，防碰撞推挤）
var _fixed_position: Vector2 = Vector2.ZERO
## 小怪生成循环是否运行中
var _minion_loop_running: bool = false


func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	# 初始化 AI 组件（BOSS4 攻击循环不依赖 AI 决策，仅避免组件 _process 访问空引用报错）
	ai_component.initialize(self)

	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.modulate.a = 0.0

	# 建筑 BOSS：锁定固定坐标
	_fixed_position = global_position

	# 骷髅头初始播放 idle（女人身体由场景 autoplay="default" 自动播放）
	if head_animated and head_animated.sprite_frames and head_animated.sprite_frames.has_animation("idle"):
		head_animated.play("idle")

	_tween_spawn_in()

	# 生成后播放战斗 BGM（参考其他 Boss，延迟 1 秒）
	get_tree().create_timer(1.0).timeout.connect(func():
		AudioManager.play_sound(&"zhandou2")
	, CONNECT_ONE_SHOT)

	# 启动小怪（hopper_monster）生成循环：每 spawn_minion_interval 秒在 Marker2D6 生成 1 个
	_run_minion_spawn_loop()


func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)


func _physics_process(_delta: float) -> void:
	if is_dead:
		return
	state_machine.physics_update(_delta)
	# 建筑 BOSS 固定不动：锁定坐标，不移动、不受推挤
	velocity = Vector2.ZERO
	global_position = _fixed_position


func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	if animated_sprite:
		animated_sprite.flip_h = facing_direction < 0
	if head_animated:
		head_animated.flip_h = facing_direction < 0


func _on_took_damage(damage: int, _is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is BossAppearState:
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	AudioManager.play_sound(&"shoushang")
	if current_hp <= 0:
		_die()
	else:
		# 建筑 BOSS：无剑术重伤特效（is_heavy 忽略），任意伤害只对骷髅头闪白
		_flash_head_white()


## 死亡入口：交给 BossDeathDirector（红黑剪影 + 定格 + 横斩），没有则直接进入死亡状态
func _die() -> void:
	_stop_minion_spawn_loop()
	var director = get_node_or_null("BossUI/BossDeathDirector") as BossDeathDirector_4
	if director:
		director.play_death_sequence(self)
	else:
		state_machine.change_state_by_name("BossDeathState")


func die() -> void:
	is_dead = true
	_stop_minion_spawn_loop()
	is_enhanced = false
	set_physics_process(false)
	set_process(false)
	# 关闭骷髅头受伤框
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	# 关闭身体全部攻击碰撞框（AttackRoot/EnemyHitBox 下所有 Area2D）
	var attack_root = get_node_or_null("AttackRoot")
	if attack_root:
		for child in attack_root.get_children():
			if child is Area2D:
				child.set_deferred("monitoring", false)
				child.set_deferred("monitorable", false)
	# 关闭底座碰撞
	var body_collision = get_node_or_null("CollisionShape2D") as CollisionShape2D
	if body_collision:
		body_collision.set_deferred("disabled", true)


## 受伤闪白：只对骷髅头（HeadAnimatedSprite2D）短暂闪白
func _flash_head_white() -> void:
	if not head_animated:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(head_animated, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(head_animated, "modulate", Color.WHITE, 0.15)


# ==================== 建筑 BOSS 的空实现（基类接口） ====================

func is_ground_ahead() -> bool:
	return true


func get_ground_at(x_pos: float) -> Vector2:
	return Vector2(x_pos, global_position.y)


# ==================== 小怪（hopper_monster）生成 ====================

## 小怪生成循环：每 spawn_minion_interval 秒生成 1 个，boss 死亡后自动停止
func _run_minion_spawn_loop() -> void:
	if _minion_loop_running:
		return
	_minion_loop_running = true
	while not is_dead:
		# 玩家死亡导致场景重载时本节点会离开场景树，需安全退出，否则 await 恢复后 get_tree() 返回 null
		if not is_inside_tree():
			break
		var interval: float = 8.0
		var d: BossData_4 = data as BossData_4
		if d:
			interval = d.spawn_minion_interval
		await get_tree().create_timer(interval).timeout
		if is_dead or not is_inside_tree():
			break
		_spawn_minion()
	_minion_loop_running = false


## 在 Marker2D6 位置生成 1 个 hopper_monster，带随机左右偏移（±minion_spawn_offset）
func _spawn_minion() -> void:
	var m6 = get_node_or_null("BossMark/Marker2D6") as Marker2D
	if not m6:
		return
	var d: BossData_4 = data as BossData_4
	var offset: float = d.minion_spawn_offset if d else 20.0
	var minion = HOPPER_SCENE.instantiate()
	var enemys = get_tree().current_scene.get_node_or_null("enemys")
	if enemys:
		enemys.add_child(minion)
	else:
		get_tree().current_scene.add_child(minion)
	# 先进树再设置绝对位置（生成点 = Marker2D6 + 随机左右偏移）
	minion.global_position = m6.global_position + Vector2(randf_range(-offset, offset), 0.0)


## 停止小怪生成循环（死亡时调用）
func _stop_minion_spawn_loop() -> void:
	is_dead = true
	_minion_loop_running = false
