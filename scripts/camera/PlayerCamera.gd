extends Camera2D

class_name PlayerCamera

@export var lock_y: bool = true
@export var fixed_y: float = 0.0

func _ready() -> void:
	top_level = true
	if fixed_y == 0.0:
		var parent = get_parent()
		if parent:
			fixed_y = parent.global_position.y + position.y

func _physics_process(_delta: float) -> void:
	var target = get_parent()
	if not target:
		return
	global_position.x = target.global_position.x
	if lock_y:
		global_position.y = fixed_y
	else:
		global_position.y = target.global_position.y

	# 手动 clamp，双重保险（Camera2D 自带 limit 有时在 top_level 下不生效）
	var viewport_half = get_viewport_rect().size.x * 0.5
	global_position.x = clampf(global_position.x, limit_left + viewport_half, limit_right - viewport_half)


# ════════════════════════════════════════════════════
#  公开接口（供关卡场景或脚本调用）
# ════════════════════════════════════════════════════

## 切换 Y 轴跟随模式
##  - true: 摄像机跟随玩家上下移动
##  - false: 锁定当前 Y 位置，不再上下跟随
func set_follow_y(follow: bool) -> void:
	lock_y = not follow
	if lock_y:
		fixed_y = global_position.y


## 设置摄像机边界（防止摄像机超出场景范围）
##  传 -1 表示不限制该方向
func set_bounds(left: float = -1, right: float = -1, top: float = -1, bottom: float = -1) -> void:
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
