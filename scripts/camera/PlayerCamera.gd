extends Camera2D

class_name PlayerCamera

@export var lock_x: bool = false
@export var lock_y: bool = true
@export var fixed_x: float = 0.0
@export var fixed_y: float = 0.0

func _ready() -> void:
	top_level = true
	if fixed_y == 0.0:
		var parent = get_parent()
		if parent:
			fixed_y = parent.global_position.y + position.y
	if fixed_x == 0.0:
		var parent = get_parent()
		if parent:
			fixed_x = parent.global_position.x + position.x

func _physics_process(_delta: float) -> void:
	var target = get_parent()
	if not target:
		return

	if lock_x:
		global_position.x = fixed_x
	else:
		global_position.x = target.global_position.x

	if lock_y:
		global_position.y = fixed_y
	else:
		global_position.y = target.global_position.y

	var viewport_size = get_viewport_rect().size
	var viewport_half_x = viewport_size.x * 0.5
	var viewport_half_y = viewport_size.y * 0.5

	global_position.x = clampf(global_position.x, limit_left + viewport_half_x, limit_right - viewport_half_x)
	global_position.y = clampf(global_position.y, limit_top + viewport_half_y, limit_bottom - viewport_half_y)


# ════════════════════════════════════════════════════
#  公开接口（供关卡场景或脚本调用）
# ════════════════════════════════════════════════════

## 切换 X 轴跟随模式
##  - true:  摄像机跟随玩家左右移动（横版关卡默认行为）
##  - false: 锁定当前 X 位置，不再左右跟随（纵向关卡使用）
##  注意：必须先调用此方法设置 lock_x，再设置 fixed_x 值才会生效
func set_follow_x(follow: bool) -> void:
	lock_x = not follow
	if lock_x:
		fixed_x = global_position.x


## 切换 Y 轴跟随模式
##  - true:  摄像机跟随玩家上下移动（纵向关卡使用）
##  - false: 锁定当前 Y 位置，不再上下跟随（横版关卡默认行为）
##  注意：必须先调用此方法设置 lock_y，再设置 fixed_y 值才会生效
func set_follow_y(follow: bool) -> void:
	lock_y = not follow
	if lock_y:
		fixed_y = global_position.y


## 设置摄像机边界（防止摄像机超出场景范围）
##  传 -1 表示不限制该方向
func set_bounds(left: int = -1, right: int = -1, top: int = -1, bottom: int = -1) -> void:
	if left != -1:
		limit_left = left
	if right != -1:
		limit_right = right
	if top != -1:
		limit_top = top
	if bottom != -1:
		limit_bottom = bottom


## 清除所有边界限制
func clear_bounds() -> void:
	limit_left = -1000000
	limit_right = 1000000
	limit_top = -1000000
	limit_bottom = 1000000
