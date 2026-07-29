# res://scripts/environment/CameraZone.gd
extends Area2D
class_name CameraZone

## 🔒 进入区域后是否锁定 X 轴
## 勾选 = 不跟随玩家水平移动，固定在当前位置+偏移
## 不勾选 = 跟随玩家左右移动
@export var lock_x: bool = false
## 🔒 进入区域后是否锁定 Y 轴
## 勾选 = 不跟随玩家垂直移动，固定在当前位置+偏移
## 不勾选 = 跟随玩家上下移动
@export var lock_y: bool = false
## ➡️ 相对当前摄像机位置的 X 偏移（像素）
## 正数 = 右移   负数 = 左移
@export var offset_x: float = 0.0
## ⬇️ 相对当前摄像机位置的 Y 偏移（像素）
## 正数 = 下移   负数 = 上移
@export var offset_y: float = 0.0
## ⏳ 过渡平滑时间（秒），默认 0.5 秒
## 进入和离开区域时，摄像机从当前位置平滑移动到目标位置
## 0 = 瞬间切换无过渡
@export var transition_duration: float = 0.5

var _saved_lock_x: bool
var _saved_lock_y: bool
var _saved_fixed_x: float
var _saved_fixed_y: float
var _camera: PlayerCamera
var _has_saved_state: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	_camera = body.get_node_or_null("Camera2D") as PlayerCamera
	if not _camera:
		return

	# 只在第一次进入时保存摄像机模式状态（用于离开时恢复）
	if not _has_saved_state:
		_has_saved_state = true
		_saved_lock_x = _camera.lock_x
		_saved_lock_y = _camera.lock_y
		_saved_fixed_x = _camera.fixed_x
		_saved_fixed_y = _camera.fixed_y

	# 始终基于摄像机当前实际位置计算目标，防止重复进出时位置跳变
	var target_fixed_x = _camera.global_position.x + offset_x
	var target_fixed_y = _camera.global_position.y + offset_y

	_camera.smooth_transition(lock_x, lock_y, target_fixed_x, target_fixed_y, transition_duration)


func _on_body_exited(body: Node2D) -> void:
	if not body is Player or not _camera:
		return

	var player := body as Player
	var restore_fixed_x = _saved_fixed_x if _saved_lock_x else player.global_position.x
	var restore_fixed_y = _saved_fixed_y if _saved_lock_y else player.global_position.y

	_camera.smooth_transition(_saved_lock_x, _saved_lock_y,
							  restore_fixed_x, restore_fixed_y, transition_duration)
