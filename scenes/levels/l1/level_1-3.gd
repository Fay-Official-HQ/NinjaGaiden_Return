extends Node2D


# ════════════════════════════════════════════════════════════
#  横版关卡 & 纵向关卡 — 相机配置速查表
# ════════════════════════════════════════════════════════════
#
#  场景                        X方向       Y方向       边界设置
# ────────────────────────────────────────────────────────────
#  Level_1 (横版)              跟随玩家     锁定Y        左右边界
#  Level_1-2 (横版)            跟随玩家     锁定Y        左右边界
#  Level_1-3 (纵向关卡↓)      锁定X不动    跟随玩家↑↓   上下边界
#
#  详细参数说明：
#
#  ┌─ 水平关卡（默认，如 Level_1, Level_1-2）──────────────┐
#  │  cam.set_bounds(left, right)         # 只设左右边界   │
#  │  cam.offset.y = -150                 # 可选垂直偏移   │
#  │  # lock_y 默认 true，lock_x 默认 false，无需额外设置  │
#  └────────────────────────────────────────────────────────┘
#
#  ┌─ 纵向关卡（如 Level_1-3）──────────────────────────────┐
#  │  cam.set_follow_x(false)   # 锁定X → 相机不左右移动    │
#  │  cam.set_follow_y(true)    # 跟随Y → 相机上下跟随玩家  │
#  │  cam.fixed_x = 400         # 锁定在X=400(调到你居中)   │
#  │  cam.set_bounds(-1, -1, top, bottom)  # 只设上下边界   │
#  │  cam.offset.y = -50        # 可选垂直偏移微调画面位置  │
#  │  # -1 传给 left/right 表示沿用引擎默认，不限制水平    │
#  └────────────────────────────────────────────────────────┘
#
#  ⚠️  旧的 .set_bounds(left, right) 只传2个参数时，
#      top/bottom 默认为 -1（不限制），完全兼容以前关卡
# ════════════════════════════════════════════════════════════

func _ready() -> void:
	SceneTransition.set_overlay_alpha(0.0)
	AudioManager.play_sound(&"bgml1")

	# 根据入口点定位玩家
	_place_player_at_entry()

	# ── 纵向关卡相机配置 ──
	var cam = $Player/Camera2D

	# step1: 锁定 X 轴，相机不再左右跟随玩家
	#        玩家水平左右移动时，画面原地不动
	cam.set_follow_x(false)

	# step2: 开启 Y 轴跟随，相机上下跟随玩家移动
	#        玩家向上跳时画面上移，向下掉落时画面下移
	cam.set_follow_y(true)

	# step3: 设置相机锁定的 X 坐标（单位：像素）
	#        调到你关卡中玩家垂直通道的中间位置
	#        测试方法：进游戏上下移动，看画面是否水平居中
	#        偏左→增大数值，偏右→减小数值
	cam.fixed_x = 400

	# step4: 设置上下边界（单位：像素）
	#        top：爬到关卡顶部时，相机停止上移的位置
	#        bottom：掉到底部时，相机停止下移的位置
	#        调大 top（负更多）= 相机能跟到更高处
	#        调小 bottom = 相机能跟到更低处
	#        测试方法：爬到头/掉到底，看是否露出边界外的空白
	cam.set_bounds(-1, -1, -140, 430)

	# step5（可选）：垂直偏移微调
	#        正值=画面下移（玩家位置偏上），负值=画面上移（玩家位置偏下）
	#        cam.offset.y = -50，你可以改成其他值
	cam.offset.y = 0



# ============================================================
#  入口点定位：将玩家传送到对应 Marker2D 的位置
# ============================================================
# 使用方式：
#   LevelManager.spawn_point = "entry_left"
#   get_tree().change_scene_to_file("res://...")
# ============================================================

func _place_player_at_entry() -> void:
	var entry_name = LevelManager.spawn_point
	LevelManager.spawn_point = "default"

	var entry = get_node_or_null(entry_name)
	if entry and entry is Marker2D:
		$Player.global_position = entry.global_position
		print("玩家从入口 %s 进入" % entry_name)
