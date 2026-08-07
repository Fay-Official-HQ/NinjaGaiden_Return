# ============================================================
# 文件：helicopter.gd
# 作用：直升机组件。玩家进入触发区域（CollisionShape2D 矩形）后，
#       直升机等待 1 秒，然后沿 Mark/WayPostion 下的 way1、way2……
#       路径点依次飞行，最终抵达 Mark/TargetPosition 并悬停上下浮动。
#       三状态：待机(IDLE) / 飞行(FLYING) / 到达(ARRIVED)
# ============================================================
extends CharacterBody2D
class_name Helicopter

# ==================== 外部可调参数（Inspector 调试用） ====================
## 飞行速度（像素/秒），默认 60
@export_range(10.0, 300.0, 1.0) var flight_speed: float = 60.0
## 待机 / 到达时上下浮动幅度（像素），默认 50
@export_range(1.0, 200.0, 1.0) var hover_amplitude: float = 50.0
## 浮动速度（弧度/秒，越大浮动越快），默认 1.5
@export_range(0.1, 10.0, 0.1) var hover_speed: float = 1.5
## 玩家进入触发区域后，直升机等待多少秒再起飞，默认 1 秒
@export_range(0.0, 5.0, 0.1) var wait_time: float = 1.0
## 触发区域放大倍数：以 CollisionShape2D 为准，1.0=原尺寸，2.0=扩大一倍
@export_range(0.5, 5.0, 0.1) var trigger_expand: float = 1.0
## 悬挂跟随开关：玩家悬挂在平台下时是否随直升机移动（默认开）。
## 直升机浮动/飞行会上下左右移动，若不跟随，玩家会脱手掉落
@export var hang_follow: bool = true
## BGM 触发半径（像素）：玩家进入该范围内播放 zhishengji，走出范围停止播放
@export_range(50.0, 1000.0, 10.0) var bgm_radius: float = 240.0
## 直升机触发 BGM 的事件 ID（SoundRegistry 中登记）
const BGM_EVENT_ID: StringName = &"zhishengji"

enum HelicopterState { IDLE, FLYING, ARRIVED }

# ==================== 内部状态变量 ====================
var state: HelicopterState = HelicopterState.IDLE
var _triggered: bool = false
var _wait_timer: float = 0.0
var _float_phase: float = 0.0
## 上下浮动的基准位置（待机=出生位置，到达=TargetPosition）
var _home_position: Vector2 = Vector2.ZERO
## 飞行路径点：way1..wayN + TargetPosition
var _path_points: Array[Vector2] = []
var _path_index: int = 0
## 上一物理帧的位置，用于计算本帧位移（悬挂跟随用）
var _last_global_pos: Vector2 = Vector2.ZERO
## BGM 是否正在播放（防止每帧重复调用 play_sound / stop_bgm）
var _bgm_playing: bool = false

@onready var _trigger_shape: CollisionShape2D = $CollisionShape2D


# ==================== 初始化 ====================
func _ready() -> void:
	_home_position = global_position
	_last_global_pos = global_position
	# 收集路径点：Mark/WayPostion 下所有子节点（way1、way2……按场景树顺序），
	# 最后追加 Mark/TargetPosition 作为终点
	var way_node: Node2D = $Mark/WayPostion
	for child in way_node.get_children():
		if child is Marker2D:
			_path_points.append((child as Marker2D).global_position)
	_path_points.append(($Mark/TargetPosition as Marker2D).global_position)


func _physics_process(delta: float) -> void:
	match state:
		HelicopterState.IDLE:
			_hover(delta, _home_position)
			if not _triggered:
				_try_trigger()
			elif _wait_timer > 0.0:
				_wait_timer -= delta
				if _wait_timer <= 0.0:
					_start_flight()
		HelicopterState.FLYING:
			_fly(delta)
		HelicopterState.ARRIVED:
			_hover(delta, _home_position)
	# 距离检测：玩家在 bgm_radius 内播放 zhishengji，走出范围停止
	_update_bgm()
	# 移动完成后，把本帧位移同步给悬挂在平台下的玩家（保证浮动/飞行时不脱手）
	_carry_hanging_player()


# ==================== BGM 距离触发 ====================
## 每帧检测玩家与直升机的距离：
## ≤ bgm_radius 播放 zhishengji（SFX 叠加播放），> bgm_radius 停止该音效。
## 用 _bgm_playing 标记避免每帧重复调用播放/停止。
## 注意：zhishengji 已改为 SFX，必须用 stop_sfx 按事件停止，
## 不能调用 stop_bgm()（那会误停场景自身的背景音乐）。
func _update_bgm() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var dist: float = global_position.distance_to(player.global_position)
	if dist <= bgm_radius:
		if not _bgm_playing:
			_bgm_playing = true
			AudioManager.play_sound(BGM_EVENT_ID)
	elif _bgm_playing:
		_bgm_playing = false
		AudioManager.stop_sfx(BGM_EVENT_ID)


## 场景卸载时停止该音效，避免切换关卡后 zhishengji 残留播放
func _exit_tree() -> void:
	if _bgm_playing:
		_bgm_playing = false
		AudioManager.stop_sfx(BGM_EVENT_ID)


# ==================== 悬挂跟随 ====================
## 玩家悬挂在平台下沿时相对平台的固定偏移（像素），与 HangState 的吸附偏移一致
const HANG_Y_OFFSET: float = 12.0

## 玩家正悬挂在本平台（HangingPlatform，Wire 结构）下时：
## y 锁定在平台下沿下方固定偏移（始终贴合，不脱手、不脱离精灵图）；
## x 跟随平台水平位移（直升机飞行时被带着走，不会被甩掉），
## 玩家仍可主动左右爬动，移出平台范围后由 HangState 自然掉落
func _carry_hanging_player() -> void:
	var motion: Vector2 = global_position - _last_global_pos
	_last_global_pos = global_position
	if not hang_follow:
		return
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	# 仅当玩家处于悬挂状态才跟随（站立时由物理承载，不需要手动带动）
	var state_machine: Node = player.get("state_machine")
	if not state_machine:
		return
	var current_state: Node = state_machine.get("current_state")
	if current_state == null or not (current_state is HangState):
		return
	var platform := $HangingPlatform
	var shape_node: CollisionShape2D = platform.get_node_or_null("CollisionShape2D")
	if not shape_node:
		return
	var shape := shape_node.shape as RectangleShape2D
	if shape == null:
		return
	var half: Vector2 = shape.size * 0.5
	# 玩家水平位置已超出平台范围（爬出边缘）：不再锁定，交给自然掉落
	if absf(player.global_position.x - global_position.x) > half.x + 36.0:
		return
	var bottom: float = shape_node.global_position.y + half.y
	# y：始终锁定在平台下沿下方固定偏移，跟随浮动但绝不脱离、绝不脱手
	player.global_position.y = bottom + HANG_Y_OFFSET
	# x：跟随平台水平位移，保持相对位置（玩家主动左右移动不受影响）
	player.global_position.x += motion.x


# ==================== 触发检测 ====================
## 检测玩家是否进入 CollisionShape2D 矩形（可被 trigger_expand 放大）
func _try_trigger() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if not player or not is_instance_valid(player):
		return
	var shape := _trigger_shape.shape as RectangleShape2D
	if shape == null:
		return
	var size: Vector2 = shape.size * trigger_expand
	var rect := Rect2(_trigger_shape.global_position - size * 0.5, size)
	if rect.has_point(player.global_position):
		_triggered = true
		_wait_timer = wait_time


# ==================== 飞行 ====================
func _start_flight() -> void:
	state = HelicopterState.FLYING
	_path_index = 0


## 沿路径点逐点飞行，全部走完后进入到达状态
func _fly(delta: float) -> void:
	var step: float = flight_speed * delta
	while _path_index < _path_points.size():
		var target: Vector2 = _path_points[_path_index]
		var dist: float = global_position.distance_to(target)
		if dist <= step:
			# 足够近：直接到点，继续下一个路径点
			global_position = target
			_path_index += 1
		else:
			# 朝目标移动本帧步长
			global_position = global_position.move_toward(target, step)
			return
	_arrive()


## 到达目的地：改基准点为飞行终点（_ready 时收集的固定世界坐标），恢复上下浮动。
## 注意：不能用 $Mark/TargetPosition.global_position —— 它是直升机的子节点，
## 直升机飞抵目标后它已随直升机偏移，会导致直升机瞬移"消失"。
func _arrive() -> void:
	state = HelicopterState.ARRIVED
	if _path_points.is_empty():
		_home_position = global_position
	else:
		_home_position = _path_points.back()
	_float_phase = 0.0


# ==================== 悬停浮动 ====================
## 以 base 为基准做正弦上下浮动，幅度 hover_amplitude 像素
func _hover(delta: float, base: Vector2) -> void:
	_float_phase += hover_speed * delta
	global_position = Vector2(base.x, base.y + sin(_float_phase) * hover_amplitude)
