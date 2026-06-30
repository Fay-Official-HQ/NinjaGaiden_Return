extends CanvasLayer

var _overlay: ColorRect
var _transitioning: bool = false


func _ready() -> void:
	process_mode = PROCESS_MODE_ALWAYS
	layer = 128

	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_overlay)


## 画面从当前状态渐变为全黑，然后切换场景
func fade_to_scene(scene_path: String, spawn_point: String = "default",
				   duration: float = 2.0) -> void:
	if _transitioning:
		return
	_transitioning = true

	get_tree().paused = true
	AudioManager.fade_out_bgm(duration)

	_overlay.color = Color(0, 0, 0, 0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(func(v): _overlay.color.a = v, 0.0, 1.0, duration) \
		 .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

	get_tree().paused = false

	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.save(player)

	LevelManager.spawn_point = spawn_point
	get_tree().change_scene_to_file(scene_path)


## 场景加载完成后调用，从全黑淡入到正常画面
func fade_in(duration: float = 1.0) -> void:
	_transitioning = false
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.color = Color(0, 0, 0, 1)

	var tween = create_tween().set_process_mode(Tween.TWEEN_PROCESS_IDLE)
	tween.tween_method(func(v): _overlay.color.a = v, 1.0, 0.0, duration) \
		 .set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

	_overlay.color.a = 0.0


## 直接设置遮罩透明度（供紧急情况使用）
func set_overlay_alpha(alpha: float) -> void:
	_overlay.color.a = alpha

## 安全清除遮罩：先保持全黑，等一帧新场景渲染完后才清除，防止场景切换瞬间闪白/闪瓦片
func clear_overlay_safe() -> void:
	_overlay.color.a = 1.0
	await get_tree().process_frame
	_overlay.color.a = 0.0
