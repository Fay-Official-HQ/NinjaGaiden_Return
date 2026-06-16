extends Node2D

# ============================================================
#  变量区 — 状态标记
# ============================================================

## Logo 是否已完全淡入显示完毕
## Logo 淡入阶段是否已开始（此时可按空格打断）
var logo_fading := false
## Logo 是否已完全淡入显示完毕
var logo_visible := false
## 菜单是否已激活（玩家正在选择选项）
var menu_active := false
## 当前选中的菜单项索引（0=GameStart, 1=Instructions）
var _selected_index := 0
## 是否正在执行场景切换过渡（防止重复触发）
var _transitioning := false

# ============================================================
#  常量 & 配置区
# ============================================================

## 菜单选项列表：每个选项记录了它的 Y 坐标和对应的动作名称
## 以后要加新选项（如 "设置"、"退出"），往这里加一项即可
var _menu_items := [
	{ "y": 151, "action": "start_game" },
	{ "y": 167, "action": "show_instructions" },
]

## Cursor 光标指向第一个选项（GameStart）时的 Y 位置
const CURSOR_BASE_Y := 152.0
## 每个菜单选项之间的垂直间距
const MENU_ITEM_GAP := 16.0

## Logo 淡入持续时间（秒）
const LOGO_FADE_DURATION := 2.0
## 菜单淡出持续时间（秒）
const MENU_FADE_DURATION := 1.0

# ============================================================
#  节点引用区 — @onready 自动绑定
# ============================================================

@onready var logo: Sprite2D = $Logo
@onready var menu: Node2D = $Menu
@onready var black_overlay: ColorRect = $BlackOverlay
@onready var logo_click_sfx: AudioStreamPlayer = $LogoClick
@onready var menu_click_sfx: AudioStreamPlayer = $MenuClick
@onready var cursor: Sprite2D = $Menu/Cursor

# 存放当前运行的 Tween，方便随时打断
var _logo_tween: Tween

# ============================================================
#  生命周期 — _ready / _exit_tree
# ============================================================

func _ready():
	# 隐藏 HUD（autoload UIManager 默认全局显示，标题场景不需要它）
	UIManager.visible = false
	# 初始状态：Logo 完全透明，菜单隐藏
	logo.modulate.a = 0.0
	menu.visible = false
	menu.position = Vector2.ZERO
	# 黑屏停留 1 秒，然后开始淡入 Logo
	await get_tree().create_timer(1.0).timeout
	# Logo 淡入阶段开始，此时按空格可提前打断
	_fade_in_logo()

func _exit_tree() -> void:
	# 切到关卡场景时恢复 HUD 显示
	UIManager.visible = true

# ============================================================
#  Logo 淡入动画（2秒，可按空格打断）
# ============================================================

func _fade_in_logo():
	logo_fading = true
	_logo_tween = create_tween()
	# 用 Tween 在 2 秒内将 Logo 透明度从 0 渐变到 1
	_logo_tween.tween_property(logo, "modulate:a", 1.0, LOGO_FADE_DURATION)
	await _logo_tween.finished
	# 自然淡入完成，标记状态
	if logo_fading:
		logo_fading = false
		logo_visible = true

## 玩家按空格提前打断 Logo 淡入，直接进入菜单
func _skip_to_menu():
	if _logo_tween and _logo_tween.is_valid():
		_logo_tween.kill()
	logo_fading = false
	logo_visible = false
	logo.modulate.a = 1.0
	_switch_to_menu()

# ============================================================
#  输入处理 — 按键分发
# ============================================================

func _input(event):
	if event.is_echo():
		return

	# 正在场景切换过渡中，忽略所有输入
	if _transitioning:
		return

	if event.is_action_pressed("pass"):
		# 阶段1：Logo 淡入中或已完全显示 → 切换到菜单
		if (logo_fading or logo_visible) and not menu_active:
			if logo_fading:
				_skip_to_menu()
			else:
				_switch_to_menu()
		# 阶段2：菜单激活时 → 确认当前选项
		elif menu_active:
			_confirm_selection()

	if menu_active:
		if event.is_action_pressed("nav_up"):
			_move_cursor(-1)
		elif event.is_action_pressed("nav_down"):
			_move_cursor(1)

# ============================================================
#  菜单切换 — CRT 故障撕裂/像素重组特效
# ============================================================

func _switch_to_menu():
	menu_active = true
	_selected_index = 0

	logo_click_sfx.play()

	# 1. 隐藏 Logo，显示菜单（设置初始故障状态）
	logo.visible = false
	menu.visible = true
	menu.modulate = Color.CYAN        # 偏色：青色
	menu.position.x = -30.0           # 初始左移

	# 2. 快速抖动 + 颜色恢复（0.2 秒内完成）
	var tween1 = create_tween()
	tween1.set_parallel(true)         # 并行执行以下动画
	tween1.tween_property(menu, "position:x", 20.0, 0.05)   # 右移
	tween1.tween_property(menu, "position:x", -15.0, 0.05).set_delay(0.05) # 左移
	tween1.tween_property(menu, "position:x", 10.0, 0.05).set_delay(0.1)   # 再右
	tween1.tween_property(menu, "position:x", 0.0, 0.05).set_delay(0.15)   # 归中
	tween1.tween_property(menu, "modulate", Color.WHITE, 0.2)  # 颜色恢复正常

	# 4. 光标先隐藏，等抖动结束后弹入
	cursor.visible = false
	_update_cursor_position()

	# 5. 抖动结束后显示光标，并加上弹跳效果
	var tween2 = create_tween()
	tween2.tween_interval(0.25)       # 等待抖动完成
	tween2.tween_callback(_show_cursor_with_bounce)

# ============================================================
#  光标移动
# ============================================================

## direction: -1 上移, 1 下移
func _move_cursor(direction: int):
	var prev := _selected_index
	# clampi 确保不会越界（到顶/到底不再移动）
	_selected_index = clampi(_selected_index + direction, 0, _menu_items.size() - 1)
	# 只有选项确实发生了变化时才更新 Cursor 位置（不播放音效）
	if _selected_index != prev:
		_update_cursor_position()

func _update_cursor_position():
	# Cursor 的 Y 位置 = 基准位置 + 选项序号 × 间距
	cursor.position.y = CURSOR_BASE_Y + _selected_index * MENU_ITEM_GAP

# ============================================================
#  选项确认 — 执行功能
# ============================================================

func _confirm_selection():
	# 标记正在过渡，屏蔽所有按键输入
	_transitioning = true

	# 播放菜单确认音效
	menu_click_sfx.play()

	var action = _menu_items[_selected_index]["action"]
	match action:
		"start_game":
			# 菜单简单淡出 1 秒，然后进入过场动画
			var tween = create_tween()
			tween.tween_property(menu, "modulate:a", 0.0, MENU_FADE_DURATION)
			await tween.finished
			const CutsceneScript = preload("res://scripts/ui/Cutscene.gd")
			CutsceneScript.target_chapter = 1
			get_tree().change_scene_to_file("res://scenes/ui/Cutscene.tscn")
		"show_instructions":
			# 操作说明功能待实现，先恢复输入
			_transitioning = false
			print("操作说明功能待实现")


# 光标弹入（带弹性缩放）
func _show_cursor_with_bounce():
	cursor.visible = true
	cursor.scale = Vector2(1.5, 1.5)
	var tween = create_tween()
	tween.tween_property(cursor, "scale", Vector2(1.0, 1.0), 0.25)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
