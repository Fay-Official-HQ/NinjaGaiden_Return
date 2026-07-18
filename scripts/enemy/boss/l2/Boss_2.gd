extends Boss
class_name Boss_2

@onready var energy_animated: AnimatedSprite2D = $Visual/EnergyAnimated
@onready var fire_animated: AnimatedSprite2D = $Visual/FireAnimated

var _camera_ref: Camera2D
var _camera_offset: Vector2
var _anchor_enabled: bool = true
var _huoxian_active: bool = false

## 火线发射间隔（秒），可在编辑器中调整
@export var huoxian_interval: float = 2.0
## 火线自动触发的血量阈值（低于此值时自动发射），可在编辑器中调整
@export var huoxian_hp_threshold: int = 13
## 火线预警时间（秒），可在编辑器中调整
@export var huoxian_warning_time: float = 1.0
## 火线预警长度（像素），可在编辑器中调整
@export var huoxian_warning_length: float = 500.0
## 火线预警高度（像素），可在编辑器中调整
@export var huoxian_warning_height: float = 5.0
## 火线预警闪烁频率，数值越大闪烁越快
@export var huoxian_warning_frequency: float = 70.0
## 风向区域触发血量阈值（HP低于此值时自动激活），默认22
@export var wind_hp_threshold: int = 22

const HUOXIAN_POINT_NAMES: Array[String] = ["Point_B", "Point_M", "Point_T"]
var _huoxian_scene: PackedScene = preload("res://scenes/enemy/boss/l2/huoxian.tscn")

# 火线预警状态
var _huoxian_in_warning: bool = false
var _huoxian_warning_timer: float = 0.0
var _huoxian_chosen_pt_name: String = ""
var _huoxian_warning_node: Sprite2D = null
var _huoxian_yujin_sprite: Sprite2D = null  # 当前显示的 Huoxianyujin 精灵引用

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	ai_component.initialize(self)
	_camera_ref = get_viewport().get_camera_2d()
	add_to_group("boss_2")

	# 飞行怪物穿透所有地形（移除 Platform/stop/ClimbableWall 碰撞）
	collision_mask = 16  # 只保留 PlayerAttack 层

	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.play("appear")
		animated_sprite.modulate.a = 0.0

	# 记录初始摄像机锚点偏移
	if _camera_ref:
		_camera_offset = global_position - _camera_ref.global_position
	else:
		_camera_offset = Vector2(data.camera_offset_x, data.camera_offset_y)

	_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)
	_sync_gold_overlay()
	# 火线预警闪烁
	if _huoxian_in_warning:
		_update_huoxian_warning(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	state_machine.physics_update(delta)
	move_and_slide()
	# 不再全局锚定，由状态自己控制（IdleState 锚定，FlyState 自由飞行）

func _apply_camera_anchor() -> void:
	if not _anchor_enabled or not _camera_ref:
		return
	var anchor_x = _camera_ref.global_position.x + _camera_offset.x
	# 只在水平方向锚定，垂直方向留自由给 FlyState 正弦波
	global_position.x = anchor_x

## 供外部（FireWall enter_completed信号）调用，正式锚定摄像机位置
func start_boss_battle() -> void:
	if _camera_ref:
		_camera_offset = global_position - _camera_ref.global_position
	_anchor_enabled = true

## 在 FireWall 的 HuoxianPath 随机点生成火线（偏移-120px从右端进入）
func _spawn_huoxian_at(point_name: String) -> void:
	var fire_wall = get_tree().get_first_node_in_group("fire_wall") as FireWall
	if not fire_wall:
		return

	var path = fire_wall.get_node_or_null("HuoxianPath") as Node2D
	if not path:
		return

	var point = path.get_node_or_null(point_name) as Marker2D
	if not point:
		return

	var huoxian = _huoxian_scene.instantiate()
	# 火线中心对齐 HuoxianPath 点
	huoxian.global_position = fire_wall.global_position + point.position
	get_tree().current_scene.add_child.call_deferred(huoxian)
	AudioManager.play_sound(&"shitou")


## 进入预警阶段：显示 YuJin 精灵 + 在 HuoxianPath 坐标位置创建动态预警条
func _enter_huoxian_warning() -> void:
	var fire_wall = get_tree().get_first_node_in_group("fire_wall") as FireWall
	if not fire_wall:
		return

	# 随机选一个点
	_huoxian_chosen_pt_name = HUOXIAN_POINT_NAMES[randi() % HUOXIAN_POINT_NAMES.size()]

	# 1) 隐藏所有 Huoxianyujin 精灵，仅显示选中的
	var yujin_root = fire_wall.get_node_or_null("Huoxianyujin") as Node2D
	if yujin_root:
		for pn in HUOXIAN_POINT_NAMES:
			var sp = yujin_root.get_node_or_null(pn) as Sprite2D
			if sp:
				sp.visible = false
		_huoxian_yujin_sprite = yujin_root.get_node_or_null(_huoxian_chosen_pt_name) as Sprite2D
		if _huoxian_yujin_sprite:
			_huoxian_yujin_sprite.visible = true

	# 2) 在 HuoxianPath 对应点坐标位置创建动态预警条
	var path = fire_wall.get_node_or_null("HuoxianPath") as Node2D
	var pt = path.get_node_or_null(_huoxian_chosen_pt_name) as Marker2D if path else null
	var warning_pos: Vector2 = fire_wall.global_position
	if pt:
		warning_pos = fire_wall.global_position + pt.position - Vector2(0, huoxian_warning_height / 2)

	# 创建红色实心条（纯白纹理→拉伸→调红）
	var img := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	var tex := ImageTexture.create_from_image(img)
	_huoxian_warning_node = Sprite2D.new()
	_huoxian_warning_node.texture = tex
	_huoxian_warning_node.centered = false
	_huoxian_warning_node.position = warning_pos
	_huoxian_warning_node.scale = Vector2(huoxian_warning_length, huoxian_warning_height)
	_huoxian_warning_node.modulate = Color(1.0, 0.102, 0.102, 0.624)
	_huoxian_warning_node.z_index = 100
	get_tree().current_scene.add_child(_huoxian_warning_node)

	_huoxian_in_warning = true
	_huoxian_warning_timer = huoxian_warning_time


## 预警闪烁更新
func _update_huoxian_warning(_delta: float) -> void:
	_huoxian_warning_timer -= _delta

	# 闪烁效果
	if _huoxian_warning_node and is_instance_valid(_huoxian_warning_node):
		var alpha = 0.2 + sin(_huoxian_warning_timer * huoxian_warning_frequency) * 0.3
		_huoxian_warning_node.modulate = Color(1.0, 0.1, 0.1, clamp(alpha, 0.05, 1.0))

	# 预警结束 → 发射
	if _huoxian_warning_timer <= 0.0:
		_finish_huoxian_warning()


## 预警结束：隐藏 YuJin 精灵 + 销毁预警条 → 发射火线
func _finish_huoxian_warning() -> void:
	_huoxian_in_warning = false

	# 隐藏 YuJin 精灵
	if _huoxian_yujin_sprite and is_instance_valid(_huoxian_yujin_sprite):
		_huoxian_yujin_sprite.visible = false
	_huoxian_yujin_sprite = null

	# 销毁动态预警条
	if _huoxian_warning_node and is_instance_valid(_huoxian_warning_node):
		_huoxian_warning_node.queue_free()
	_huoxian_warning_node = null

	# 发射火线
	_spawn_huoxian_at(_huoxian_chosen_pt_name)

	# 安排下一次
	_schedule_next_huoxian()


## 启动火线定时循环
func start_huoxian_cycle() -> void:
	if _huoxian_active:
		return
	_huoxian_active = true
	_enter_huoxian_warning()


## 停止火线定时循环
func stop_huoxian_cycle() -> void:
	_huoxian_active = false
	_huoxian_in_warning = false
	if _huoxian_yujin_sprite and is_instance_valid(_huoxian_yujin_sprite):
		_huoxian_yujin_sprite.visible = false
	_huoxian_yujin_sprite = null
	if _huoxian_warning_node and is_instance_valid(_huoxian_warning_node):
		_huoxian_warning_node.queue_free()
	_huoxian_warning_node = null


## 安排下一次火线
func _schedule_next_huoxian() -> void:
	if is_dead:
		_huoxian_active = false
		return

	var t = get_tree().create_timer(huoxian_interval)
	t.timeout.connect(_on_huoxian_timer, CONNECT_ONE_SHOT)


func _on_huoxian_timer() -> void:
	# 防止停止火线后过期定时器重新生成预警线
	if not _huoxian_active or is_dead:
		return
	_enter_huoxian_warning()

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is BossAppearState:
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	_update_enhancement_state()
	AudioManager.play_sound(&"shoushang")

	# 血量低于阈值时自动启动火线
	if current_hp < huoxian_hp_threshold and not _huoxian_active:
		start_huoxian_cycle()

	# 血量低于阈值时激活所有风向区域（处理动态生成的 chunk）
	if current_hp < wind_hp_threshold:
		for wz in get_tree().get_nodes_in_group("boss_wind_zone"):
			wz.set_trigger_enabled(true)

	if current_hp <= 0:
		# BOSS 死亡，立即停止火线和火墙
		stop_huoxian_cycle()
		var fire_wall = get_tree().get_first_node_in_group("fire_wall") as FireWall
		if fire_wall:
			fire_wall.death_exit()
		# 关闭所有风向区域
		for wz in get_tree().get_nodes_in_group("boss_wind_zone"):
			wz.force_stop()
		var director = get_node_or_null("BossUI/BossDeathDirector") as BossDeathDirector
		if director:
			director.play_death_sequence(self)
		else:
			state_machine.change_state_by_name("BossDeathState")
	elif is_heavy:
		state_machine.change_state_by_name("BossHurtState")
	else:
		_flash_white()

func _get_block_chance() -> float:
	return 0.0

func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animated_sprite.flip_h = facing_direction < 0
	if energy_animated:
		energy_animated.flip_h = facing_direction < 0
		energy_animated.position.x = 16 * facing_direction
	if fire_animated:
		fire_animated.flip_h = facing_direction < 0
		fire_animated.position.x = 25 * facing_direction

func is_ground_ahead() -> bool:
	return true

func get_ground_at(x_pos: float) -> Vector2:
	return Vector2(x_pos, global_position.y)
