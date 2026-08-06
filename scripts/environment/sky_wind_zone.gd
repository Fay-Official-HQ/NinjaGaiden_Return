# ============================================================
# 文件：sky_wind_zone.gd
# 作用：常驻天空风区域，实例化到地图场景后自动持续刮风，
#       无触发、无文字提示、无音效、无碰撞；全图推动玩家，
#       提供开启/关闭与参数调整接口
# ============================================================
extends Node2D
class_name SkyWindZone

# ==================== 常量配置 ====================
const WIND_TEX = preload("res://assets/sprites/map/wind.png")

# ==================== 外部可调参数（Inspector） ====================
## 是否开启刮风（默认开启，实例化到地图后直接生效）
@export var enabled: bool = true
## 风力推玩家速度（像素/秒），范围10~200（玩家速度100，低风速即可减速玩家）
@export_range(10.0, 200.0) var wind_speed: float = 60.0
enum WindDir { 東, 西, 隨機 }
## 风向：東=推向右，西=推向左，隨機=开启刮风时随机选择一个方向
@export var wind_direction: WindDir = WindDir.東

# ==================== 内部状态变量 ====================
var _wind_enabled: bool = false
var _current_dir_sign: float = 1.0
var _stop_spawning: bool = false
## 风力位移累积器：玩家每帧会 position.round() 像素对齐，
## 直接推小数位移会被吞掉，这里攒满整数像素才推一次
var _push_accum: float = 0.0

@onready var _wind_container: Node2D = get_node_or_null("CanvasLayer/WindParticles")


# ==================== 初始化 ====================
func _ready() -> void:
	# 关键：process_physics_priority 值越小越先执行（官方文档）。
	# 必须设为负数，让本组件的物理处理先于玩家脚本（含其 Camera2D）执行：
	# 风先 move_and_collide 推玩家 → 玩家脚本像素取整 → 相机再锁定玩家位置。
	# 若风在玩家/相机之后才推（正优先级=最后执行），位移永远发生在相机锁定之后，
	# 渲染时角色相对镜头错位；风速不是整像素/帧时（如30=隔帧推1px），
	# 角色就会每帧来回跳 1 像素，看起来就是"角色本身抖动模糊"。
	process_physics_priority = -1000
	add_to_group("sky_wind_zone")
	set_wind_enabled(enabled)


# ==================== 每帧全图推玩家（风力持续生效） ====================
func _physics_process(delta: float) -> void:
	if not _wind_enabled:
		_push_accum = 0.0
		return
	var player: Node2D = get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		_push_accum = 0.0
		return
	# 累积风向风速位移，只推动整数像素，避免被玩家的像素取整吞掉
	_push_accum += _current_dir_sign * wind_speed * delta
	var push_x: int = int(_push_accum)  # 向零截断：不足1像素不推
	if push_x != 0:
		_push_accum -= push_x
		player.move_and_collide(Vector2(push_x, 0))


# ==================== 开启/关闭刮风接口 ====================
## 开启或关闭刮风；开启后自动生成风痕并推玩家，关闭后清理所有风痕
func set_wind_enabled(value: bool) -> void:
	_wind_enabled = value
	_push_accum = 0.0
	if value:
		_pick_direction()
		_start_wind_lines()
	else:
		_stop_wind_lines()


## 查询当前是否处于刮风状态
func is_wind_enabled() -> bool:
	return _wind_enabled


# ==================== 参数调整接口 ====================
## 运行时调整风速（自动限制在10~200范围）
func set_wind_speed(value: float) -> void:
	wind_speed = clampf(value, 10.0, 200.0)


## 运行时调整风向；若当前刮风中则立即生效
func set_wind_direction(value: WindDir) -> void:
	wind_direction = value
	if _wind_enabled:
		_pick_direction()


# ==================== 风向 ====================
func _pick_direction() -> void:
	if wind_direction == WindDir.隨機:
		_current_dir_sign = -1.0 if randf() > 0.5 else 1.0
	else:
		_current_dir_sign = 1.0 if wind_direction == WindDir.東 else -1.0


# ==================== 风力（持续生成风痕横穿屏幕） ====================
func _start_wind_lines() -> void:
	_stop_spawning = false
	var screen = get_viewport().get_visible_rect().size
	var line_count = 6 + ceili((wind_speed - 10.0) / 190.0 * 14)  # 风速10→6条，200→20条
	for i in line_count:
		_spawn_wind_line(screen)


func _spawn_wind_line(screen: Vector2) -> void:
	if not _wind_enabled or _stop_spawning or not _wind_container:
		return
	var dir = _current_dir_sign
	var sprite = Sprite2D.new()
	sprite.texture = WIND_TEX
	sprite.modulate = Color(1, 1, 1, 1)
	var s = randf_range(0.3, 2.5)
	sprite.scale = Vector2(s, s)
	sprite.position.y = roundi(randf_range(-20, screen.y + 20))
	var speed = randf_range(400.0, 800.0)
	var travel = screen.x + 120
	var delay = randf_range(0, 0.3)
	if dir > 0:
		sprite.position.x = -60
		sprite.flip_h = false
	else:
		sprite.position.x = screen.x + 60
		sprite.flip_h = true
	_wind_container.add_child(sprite)
	var start_x = sprite.position.x
	var end_x = start_x + dir * travel
	var tw = create_tween()
	tw.tween_interval(delay)
	# 逐帧取整到整数像素，避免风痕出现亚像素闪烁（像素模糊）
	tw.tween_method(func(v): sprite.position.x = roundi(v), start_x, end_x, travel / speed)
	tw.tween_callback(sprite.queue_free)
	tw.tween_callback(_spawn_wind_line.bind(screen))


func _stop_wind_lines() -> void:
	_stop_spawning = true
	if _wind_container:
		for child in _wind_container.get_children():
			child.queue_free()
