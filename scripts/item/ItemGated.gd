extends Item
class_name ItemGated

## 需要接收参数才能激活的消耗品（作用与普通 Item 完全一致）：
## 未激活时完全隐藏（不可见、不可被玩家攻击击落、不可被拾取），
## 只有外部调用 activate() 传入消耗品类型/效果参数后才会显示。
## 激活时先播放 wuye 升腾动画（AnimatedSprite2D），播放完毕后本体才显示、
## 可被击落、可被拾取。动画播放期间本体与碰撞保持隐藏，且本体不移动。

## 是否已激活
var _activated: bool = false
## 是否正在播放升腾动画（本体还未显示）
var _revealing: bool = false

@onready var _wuye_anim: AnimatedSprite2D = $AnimatedSprite2D


func _ready() -> void:
	super()
	# 升腾动画播完 → 显示本体（只播动画，不移动消耗品）
	if _wuye_anim:
		_wuye_anim.animation_finished.connect(_on_wuye_finished)
	# 兼容两种调用顺序：
	# 先 add_child 再 activate → 这里先进入隐藏态，activate 时再播放升腾
	# 先 activate 再 add_child → 这里直接开始播放升腾
	if _activated:
		_start_reveal()
	else:
		_deactivate()


## 激活接口：接收消耗品类型与效果参数，激活后播放升腾动画，播完才显示本体
## add_child 之前或之后调用都支持（参数决定加成内容，spawn_at 可选指定出生位置）
func activate(
		p_type: ConsumableType = ConsumableType.HEALTH,
		p_restore_hp: int = 8,
		p_restore_mp_small: int = 1,
		p_restore_mp_large: int = 16,
		p_restore_tp: int = 16,
		spawn_at: Vector2 = Vector2.INF
	) -> void:
	if _activated:
		return
	consumable_type = p_type
	restore_hp = p_restore_hp
	restore_mp_small = p_restore_mp_small
	restore_mp_large = p_restore_mp_large
	restore_tp = p_restore_tp
	if spawn_at != Vector2.INF:
		global_position = spawn_at
	_activated = true
	_update_textures()
	if is_inside_tree():
		_start_reveal()


## 开始升腾：本体与碰撞保持隐藏，播放 wuye 巫女祝福动画（类似 ItemSpecial：逐渐变淡 + 上升 + 放大），
## 动画播完才显示本体。本体位置保持不变，仅升腾动画移动。
func _start_reveal() -> void:
	if _revealing:
		return
	_revealing = true
	# 根节点可见（只显示升腾动画，本体与碰撞仍隐藏）
	visible = true
	# 隐藏本体与碰撞（升腾期间不可见、不可击落、不可拾取）
	if _sprite:
		_sprite.visible = false
	if _pickup_area:
		_pickup_area.set_deferred("monitoring", false)
		_pickup_area.set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0
	# 播放升腾动画 + 祝福音效
	if _wuye_anim:
		_play_blessing_sound()
		_wuye_anim.visible = true
		_wuye_anim.frame = 0
		_wuye_anim.position = Vector2.ZERO
		_wuye_anim.scale = Vector2.ONE
		_wuye_anim.modulate = Color(1, 1, 1, 0.7)
		_wuye_anim.play("wuye")
		# 与 ItemSpecial 相同的祝福效果：逐渐变淡 + 上升 + 放大（时长与动画一致）
		var anim_len := _get_wuye_anim_length()
		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(_wuye_anim, "position:y", -60.0, anim_len)
		tween.tween_property(_wuye_anim, "modulate:a", 0.0, anim_len)
		tween.tween_property(_wuye_anim, "scale", Vector2(1.1, 1.1), anim_len)
	else:
		# 没有升腾动画则直接显示本体
		_apply_activated_visuals()


## 计算 wuye 动画总时长（秒），与 ItemSpecial 一致
func _get_wuye_anim_length() -> float:
	if _wuye_anim == null or _wuye_anim.sprite_frames == null:
		return 1.0
	var frames := _wuye_anim.sprite_frames
	var fc := frames.get_frame_count("wuye")
	var length := 0.0
	for i in fc:
		length += frames.get_frame_duration("wuye", i)
	length /= frames.get_animation_speed("wuye")
	return length


## 播放祝福音效：用专属独立播放器（不经过 AudioManager 公共 SFX 池）。
## 轰炸期间音效密集（导弹爆炸 leidian 等），公共池只有 8 个播放器，
## 池满时 AudioManager 会强停第一个播放器征用，导致 yongchang 播不出或被截断。
## 独立播放器不占池、不会被征用，播放完自动释放。
func _play_blessing_sound() -> void:
	var event: SoundEventResource = SoundRegistry.get_event(&"yongchang")
	if event == null or event.stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = PROCESS_MODE_ALWAYS
	player.stream = event.stream
	player.volume_db = event.volume_db
	player.pitch_scale = event.pitch
	player.bus = event.bus
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()


## wuye 动画播完：显示本体，恢复击落/拾取
func _on_wuye_finished() -> void:
	if not _revealing:
		return
	_revealing = false
	_apply_activated_visuals()


## 未激活的隐藏状态：不可见、碰撞清零（攻击框检测不到 → 不可击落）、拾取区关闭
func _deactivate() -> void:
	visible = false
	if _sprite:
		_sprite.visible = false
	if _wuye_anim:
		_wuye_anim.visible = false
		_wuye_anim.stop()
	if _pickup_area:
		_pickup_area.set_deferred("monitoring", false)
		_pickup_area.set_deferred("monitorable", false)
	collision_layer = 0
	collision_mask = 0


## 激活后的显示状态：恢复本体、碰撞与拾取，行为与普通 Item 完全一致
func _apply_activated_visuals() -> void:
	visible = true
	if _wuye_anim:
		_wuye_anim.visible = false
		_wuye_anim.stop()
		# 重置升腾效果残留（淡出/位移/缩放）
		_wuye_anim.modulate = Color.WHITE
		_wuye_anim.position = Vector2.ZERO
		_wuye_anim.scale = Vector2.ONE
	if _sprite:
		_sprite.visible = true
	if _pickup_area:
		_pickup_area.set_deferred("monitoring", true)
		_pickup_area.set_deferred("monitorable", true)
	collision_layer = 64
	collision_mask = 16


## 未激活时不能被玩家攻击击落
func receive_attack() -> void:
	if not _activated:
		return
	super()


## 未激活时不能被玩家拾取
func _on_player_enter(body: Node2D) -> void:
	if not _activated:
		return
	super(body)


## 未激活/升腾期间不执行闪烁/下落等逻辑
func _physics_process(delta: float) -> void:
	if not _activated or _revealing:
		return
	super(delta)
