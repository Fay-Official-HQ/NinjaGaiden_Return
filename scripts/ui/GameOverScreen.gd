extends CanvasLayer


# ============================================================
#  [静态参数] 切场景前设置
# ============================================================

## 切到本场景前，设置此变量为当前关卡路径，用于"继续游戏"时重载
static var return_scene: String = ""


# ============================================================
#  [常量配置]
# ============================================================

const OVERLAY_FADE_IN := 0.5    # 黑幕遮罩淡入用时
const WHITE_FADE_TIME  := 3.0   # 放弃时画面变白用时
const WHITE_HOLD_TIME  := 0.8   # 白色停顿时间

const CURSOR_BASE_Y    := 132.0
const MENU_ITEM_GAP    := 14.0


# ============================================================
#  [节点引用]
# ============================================================

@onready var black_overlay: ColorRect = $BlackOverlay
@onready var panel: Node2D = $Panel
@onready var cursor: Sprite2D = $Panel/Cursor
@onready var confirm_sfx: AudioStreamPlayer = $ConfirmSFX
@onready var gameover_bgm: AudioStreamPlayer = $GameOverBGM


# ============================================================
#  [状态变量]
# ============================================================

var _menu_items := [
	{ "action": "continue" },
	{ "action": "quit" },
]

var _selected_index := 0
var _active := false
var _transitioning := false


# ============================================================
#  [初始化] 作为独立场景加载后自动执行
# ============================================================

func _ready():
	# 隐藏 HUD
	UIManager.visible = false

	# 初始隐藏
	panel.modulate.a = 0.0
	cursor.visible = false
	black_overlay.modulate.a = 0.0

	# 阶段1：黑幕遮罩淡入
	var tw = create_tween()
	tw.tween_property(black_overlay, "modulate:a", 0.8, OVERLAY_FADE_IN)
	await tw.finished

	# 阶段2：显示选项面板
	panel.modulate.a = 1.0
	_selected_index = 0
	_update_cursor_position()
	cursor.visible = true
	cursor.scale = Vector2(1.0, 1.0)

	_active = true


# ============================================================
#  [输入处理]
# ============================================================

func _input(event):
	if not _active or _transitioning:
		return

	if event.is_action_pressed("pass"):
		_confirm_selection()
	elif event.is_action_pressed("nav_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("nav_down"):
		_move_cursor(1)


# ============================================================
#  [光标控制]
# ============================================================

func _move_cursor(direction: int):
	var prev := _selected_index
	_selected_index = clampi(_selected_index + direction, 0, _menu_items.size() - 1)
	if _selected_index != prev:
		_update_cursor_position()

func _update_cursor_position():
	cursor.position.y = CURSOR_BASE_Y + _selected_index * MENU_ITEM_GAP


# ============================================================
#  [确认选择]
# ============================================================

func _confirm_selection():
	_transitioning = true
	_active = false

	match _menu_items[_selected_index]["action"]:
		"continue":
			confirm_sfx.play()
			_restart_level()
		"quit":
			_go_to_title()


# ============================================================
#  [继续游戏] 重载当前关卡
# ============================================================

func _restart_level():
	await get_tree().create_timer(1.0).timeout

	UIManager.visible = true
	SceneTransition.set_overlay_alpha(1.0)

	if return_scene != "":
		get_tree().change_scene_to_file(return_scene)
	else:
		push_error("GameOverScreen: return_scene 为空，无法继续游戏")


# ============================================================
#  [放弃] 画面变白 → 纯黑 → 回到标题菜单
# ============================================================

func _go_to_title():
	# 创建白色遮罩
	var white_overlay = ColorRect.new()
	white_overlay.color = Color.WHITE
	white_overlay.modulate.a = 0.0
	white_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	white_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(white_overlay)

	# 面板淡出
	var tw = create_tween()
	tw.tween_property(panel, "modulate:a", 0.0, 0.3)
	await tw.finished

	# 播放 GameOver 音乐（画面变白时同步）
	gameover_bgm.play()

	# 画面逐渐变白
	var tw_w = create_tween()
	tw_w.tween_property(white_overlay, "modulate:a", 1.0, WHITE_FADE_TIME)
	await tw_w.finished

	# 白色定格
	await get_tree().create_timer(WHITE_HOLD_TIME).timeout

	# 切纯黑
	white_overlay.color = Color.BLACK
	await get_tree().create_timer(0.3).timeout

	gameover_bgm.stop()

	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
