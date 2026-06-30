# Cutscene.gd — 过场动画脚本
# 负责：播放开场动画 → 显示章节文字 → 淡出 → 进入关卡
# ============================================================
#  使用方式
# ============================================================
# 在切换场景前设置目标章节号，然后跳转到 Cutscene：
#   Cutscene.target_chapter = 1
#   get_tree().change_scene_to_file("res://scenes/ui/Cutscene.tscn")
#
# 演出流程（自动执行，无需手动调用）：
#   忍者滑入 → 标题冲入 → 章节文字淡入 → 定格 → 遮罩变黑 → 进入关卡
# ============================================================

extends Node2D


# ============================================================
#  [静态参数] 切场景前设置这个，决定显示第几章
# ============================================================

static var target_chapter: int = 1


# ============================================================
#  [节奏配置] 所有时间在这里调，不用改下面代码
# ============================================================

const NINJA_DASH_TIME     = 0.4   # 忍者从左侧冲入屏幕的用时（秒）
const NINJA_SHAKE_TIME    = 0.2   # 忍者急停后颤抖的用时（秒）

const TITLE_CRASH_TIME    = 0.5   # 游戏标题从右侧冲入的用时（秒）
const TITLE_SHAKE_TIME    = 0.3   # 标题落地的震动用时（秒）

const TITLE_TO_TEXT_DELAY = 0.3   # 标题落地后 → 章节文字开始淡入的等待时间（秒）
const TEXT_FADE_DURATION  = 0.5   # 主标题（如"第一章"）淡入用时（秒）
const SUBTITLE_DELAY      = 0.2   # 副标题比主标题晚多久才开始淡入（秒）
const SUBTITLE_FADE_DUR   = 1.8   # 副标题淡入用时（秒）

const IDLE_HOLD_TIME      = 2.0   # 所有文字显示完后，画面定格的时长（秒）
const FADE_OUT_TIME       = 1.5   # 结尾屏幕渐黑用的时间（秒）
const SKIP_ACTION         = "pass"  # 玩家可以按这个键跳过整个演出


# ============================================================
#  [关卡映射] 章节编号 → 实际场景文件路径
#  以后加新关卡，在这里加一行即可
# ============================================================

const CHAPTER_SCENE_MAP: Dictionary = {
	1: "res://scenes/levels/Level_1.tscn",
	# 2: "res://scenes/levels/Level_2.tscn",   # 以后加新关卡在这里加
	# 3: "res://scenes/levels/Level_3.tscn",
}


# ============================================================
#  [终点坐标] 动画结束时 ninja 和 title 停在的位置
#  场景编辑器中摆放的 NinjaIcon / GameTitle 是动画起始位置
#  这里定义的是动画结束位置（它们在屏幕上的最终位置）
# ============================================================

const NINJA_END_X = 380.0   # 忍者最终 X（停在这里后颤抖）
const NINJA_END_Y = 80.0    # 忍者 Y 不变
const TITLE_END_X = 150.0   # 标题最终 X（停在这里后震动 + 回弹）
const TITLE_END_Y = 220.0   # 标题最终 Y


# ============================================================
#  [节点引用] @onready 在 _ready() 之前自动绑定
# ============================================================

@onready var ninja: Sprite2D = $NinjaIcon
@onready var title: Sprite2D = $GameTitle
@onready var black_rect: ColorRect = $ColorRect
@onready var bgm: AudioStreamPlayer = $BGM

var _chapter_root: Node2D
var _chapter_title: Sprite2D
var _chapter_subtitle: Sprite2D

var _skip: bool = false
var _transitioning: bool = false

var _fade_layer: CanvasLayer
var _fade_overlay: ColorRect


# ============================================================
#  初始化：拉起幕布、准备舞台、启动演出
# ============================================================

func _enter_tree():
	# 尽早隐藏全局 HUD，防止切场景时闪一下
	UIManager.visible = false


func _ready():
	# 永久黑色背景（ColorRect 全程 alpha=1.0，只是背景板）
	black_rect.modulate.a = 1.0

	# 创建结尾黑幕遮罩
	# CanvasLayer 的 layer=128 高于默认 0，所以遮罩永远画在所有 2D 节点之上
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 128
	add_child(_fade_layer)

	_fade_overlay = ColorRect.new()
	_fade_overlay.color = Color.BLACK
	_fade_overlay.modulate.a = 0.0          # 开始时完全透明，看不见
	_fade_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 不阻挡鼠标点击
	_fade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)  # 全屏
	_fade_layer.add_child(_fade_overlay)

	# 根据 target_chapter 找到对应的章节文字节点
	_setup_chapter(target_chapter)

	# 设置初始透明度：ninja 和 title 场景中已经可见，章节文字需要从透明开始
	_chapter_title.modulate.a = 0.0
	_chapter_subtitle.modulate.a = 0.0

	# 播放背景音乐
	bgm.play()

	# ========== 按顺序播放各个阶段 ==========

	# 阶段1：忍者从左侧滑入
	await _phase1_ninja_run()

	# 阶段2：标题从右侧冲入
	await _phase2_title_crash()

	# 阶段3：章节文字淡入（可跳过）
	if not _skip:
		await get_tree().create_timer(TITLE_TO_TEXT_DELAY).timeout
		await _phase3_text_fade()

	# 阶段4：画面定格（可跳过）
	if not _skip:
		await get_tree().create_timer(IDLE_HOLD_TIME).timeout

	# 阶段5：黑幕遮罩淡入 → 切关卡（可跳过）
	if not _skip:
		await _fade_out(FADE_OUT_TIME)

	# 进入对应关卡
	_go_to_level()


# ============================================================
#  按键跳过 — 按 pass 键直接快进到关卡
# ============================================================

func _input(event):
	# 已经在切换中，忽略后续输入
	if _transitioning:
		return

	if event.is_action_pressed(SKIP_ACTION):
		_skip = true
		# 先快速变黑再切关卡，视觉上更平滑
		_fade_overlay.modulate.a = 0.0
		var tw = create_tween()
		tw.tween_property(_fade_overlay, "modulate:a", 1.0, 0.3)
		await tw.finished
		_go_to_level()


# ============================================================
#  切关卡 — 跳转到目标关卡场景
# ============================================================

func _go_to_level():
	if _transitioning:
		return
	_transitioning = true

	UIManager.visible = true
	bgm.stop()

	var scene_path = CHAPTER_SCENE_MAP.get(target_chapter)
	if scene_path:
		get_tree().change_scene_to_file(scene_path)
	else:
		push_error("Cutscene: 未找到章节 %d 对应的关卡场景路径" % target_chapter)


# ============================================================
#  [_setup_chapter] 根据 target_chapter 找到对应文字节点
# ============================================================

func _setup_chapter(chapter: int) -> void:
	var chapter_node_path = "ChapterText/chapter_%d" % chapter
	_chapter_root = get_node(chapter_node_path)
	if not _chapter_root:
		push_error("Cutscene: 场景中缺少节点 %s" % chapter_node_path)
		return

	for child in $ChapterText.get_children():
		if child is Node2D:
			child.visible = (child == _chapter_root)

	_chapter_title = _chapter_root.get_node("title")
	_chapter_subtitle = _chapter_root.get_node("title/subtitle")

	if not _chapter_title:
		push_error("Cutscene: %s 下缺少 title 子节点" % chapter_node_path)
	if not _chapter_subtitle:
		push_error("Cutscene: %s/title 下缺少 subtitle 子节点" % chapter_node_path)


# ============================================================
#  辅助函数 — 工具方法
# ============================================================

func _fade_out(duration: float):
	var tw = create_tween()
	tw.tween_property(_fade_overlay, "modulate:a", 1.0, duration)
	await tw.finished


func _phase1_ninja_run():
	ninja.position = Vector2(-100, NINJA_END_Y)
	var tw = create_tween()
	tw.tween_property(ninja, "position:x", NINJA_END_X, NINJA_DASH_TIME).set_ease(Tween.EASE_OUT)

	for i in range(3):
		_create_afterimage(ninja.position)
		await get_tree().create_timer(0.1).timeout

	await tw.finished
	await _shake_node(ninja, 5.0, NINJA_SHAKE_TIME, true)


func _create_afterimage(pos: Vector2):
	var img = Sprite2D.new()
	img.texture = ninja.texture
	img.position = pos
	img.scale = ninja.scale
	img.modulate.a = 0.4
	add_child(img)
	var tw = create_tween()
	tw.tween_property(img, "modulate:a", 0.0, 0.2).set_delay(0.15)
	tw.tween_callback(img.queue_free)


func _shake_node(node: Node2D, amplitude: float, duration: float, horizontal: bool = true):
	var tw = create_tween()
	var count = 4
	var step = duration / (count * 2)
	for i in range(count):
		var offset = amplitude if i % 2 == 0 else -amplitude
		if horizontal:
			tw.tween_property(node, "position:x", node.position.x + offset, step)
		else:
			tw.tween_property(node, "position:y", node.position.y + offset, step)
		amplitude *= 0.6
	await tw.finished


func _phase2_title_crash():
	title.position = Vector2(550, TITLE_END_Y)
	var tw = create_tween()
	tw.tween_property(title, "position:x", TITLE_END_X, TITLE_CRASH_TIME).set_ease(Tween.EASE_OUT)

	var tw_shake = create_tween()
	tw_shake.tween_interval(TITLE_CRASH_TIME - 0.1)
	tw_shake.tween_callback(_trigger_title_land_shake)

	await tw.finished
	var tw_bounce = create_tween()
	tw_bounce.tween_property(title, "position:x", TITLE_END_X - 5, 0.08)
	tw_bounce.tween_property(title, "position:x", TITLE_END_X, 0.08)
	await tw_bounce.finished


func _trigger_title_land_shake():
	await _shake_node(title, 4.0, TITLE_SHAKE_TIME, false)


func _phase3_text_fade():
	var tw1 = create_tween()
	tw1.tween_property(_chapter_title, "modulate:a", 1.0, TEXT_FADE_DURATION)

	var tw2 = create_tween()
	tw2.tween_interval(SUBTITLE_DELAY)
	tw2.tween_property(_chapter_subtitle, "modulate:a", 1.0, SUBTITLE_FADE_DUR)
	await tw1.finished
	await tw2.finished
