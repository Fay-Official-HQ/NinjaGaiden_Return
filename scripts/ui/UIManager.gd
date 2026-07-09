extends CanvasLayer

@onready var hp_fill = $HUD/HPBarFill
@onready var mp_fill = $HUD/MPBarFill
@onready var tp_fill = $HUD/TPBarFill
@onready var ninjutsu_icon = $HUD/NinjutsuIcon
@onready var _msg_label: Label = $HUD/MessageLabel

var _msg_timer: float = 0.0

# ── 暂停系统 ──
var _pause_overlay: ColorRect
var _is_paused: bool = false
var _played_pause_sound: bool = false

var ninjutsu_textures: Array[Texture2D] = [
	preload("res://assets/sprites/ui/fire_ninjutsu.png"),
	preload("res://assets/sprites/ui/fireball_ninjutsu.png"),
	preload("res://assets/sprites/ui/boomerang_ninjutsu.png"),
	preload("res://assets/sprites/ui/edge_blade_ninjutsu.png"),
]

var cd_masks: Dictionary = {}
var cd_full_height: float = 16.0

func _ready() -> void:
	# 暂停时 UIManager 必须继续运行才能检测恢复输入
	process_mode = PROCESS_MODE_ALWAYS

	cd_masks = {
		"dash": $HUD/CD_Dash/CDMask,
		"uppercut": $HUD/CD_Uppercut/CDMask,
		"downslash": $HUD/CD_Downslash/CDMask,
		"spin": $HUD/CD_Spin/CDMask,
		"finish": $HUD/CD_Finish/CDMask,
	}
	cd_full_height = cd_masks["dash"].size.y

	_setup_pause_overlay()

func _setup_pause_overlay() -> void:
	# 半透明黑色遮罩
	_pause_overlay = ColorRect.new()
	_pause_overlay.color = Color(0, 0, 0, 0.6)
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.hide()
	add_child(_pause_overlay)


func _process(delta: float) -> void:
	# 隐藏时不处理暂停，避免和 Intro 场景的 pass 按键冲突
	if not visible:
		return

	# 暂停输入检测（玩家未死亡且Boss死亡演出未播放时才生效）
	if Input.is_action_just_pressed("pass"):
		if BossDeathDirector.is_death_playing:
			return
		var player_node = get_tree().get_first_node_in_group("player")
		if player_node and not player_node._is_dead:
			_toggle_pause()

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	_update_bar(hp_fill, player.current_hp, player.data.max_hp)
	_update_bar(mp_fill, player.ninjutsu.current_mp, player.data.max_mp)
	_update_bar(tp_fill, player.sword.current_tp, player.sword.max_tp)
	
	_update_cd_masks(player)

	# 用 is_connected 代替布尔变量：跨场景 Player 重建后自动重新连接
	if not player.ninjutsu.ninjutsu_switched.is_connected(_update_ninjutsu_icon):
		player.ninjutsu.ninjutsu_switched.connect(_update_ninjutsu_icon)
		_update_ninjutsu_icon(player.ninjutsu.current_ninjutsu_index, "")
	
	_handle_message(delta)


func _toggle_pause() -> void:
	_is_paused = not _is_paused

	if _is_paused:
		AudioManager.pause_bgm()
		Engine.time_scale = 0.0
		_pause_overlay.show()
		if not _played_pause_sound:
			AudioManager.play_sound(&"zanting")
			_played_pause_sound = true
	else:
		Engine.time_scale = 1.0
		_pause_overlay.hide()
		_played_pause_sound = false
		AudioManager.resume_bgm()

func _update_bar(bar: Sprite2D, current_value: float, max_value: float) -> void:
	if current_value <= 0:
		bar.hide()
		bar.scale.x = 0
	else:
		bar.show()
		bar.scale.x = float(current_value) / float(max_value)

func _update_cd_masks(player: Player) -> void:
	for skill_name in cd_masks.keys():
		var mask = cd_masks[skill_name]
		var remaining = player.sword.get_cooldown_remaining(skill_name)
		
		if remaining <= 0:
			mask.size.y = 0
			mask.hide()
		else:
			mask.show()
			var max_cd = player.sword.FINISH_COOLDOWN_TIME if skill_name == "finish" else player.sword.COOLDOWN_TIME
			var ratio = remaining / float(max_cd)
			mask.size.y = cd_full_height * ratio

func _update_ninjutsu_icon(index: int, _name: String) -> void:
	if index >= 0 and index < ninjutsu_textures.size():
		ninjutsu_icon.texture = ninjutsu_textures[index]

func show_message(text: String, duration: float = 1.0) -> void:
	_msg_label.text = text
	_msg_label.modulate.a = 1.0
	_msg_timer = duration

func _handle_message(delta: float) -> void:
	if _msg_timer <= 0:
		if _msg_label.visible:
			_msg_label.hide()
		return
	_msg_label.show()
	_msg_timer -= delta
	if _msg_timer < 0.3:
		_msg_label.modulate.a = _msg_timer / 0.3
