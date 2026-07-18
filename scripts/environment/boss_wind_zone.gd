# ============================================================
# 文件：wind_zone.gd
# 作用：刮风区域触发器，玩家进入后播放风声→显示文字→刮风推玩家
# ============================================================
extends Area2D
class_name BossWindZone

# ==================== 状态枚举 ====================
enum ZoneState { IDLE, WARNING, WIND, DONE }

# ==================== 常量配置 ====================
const SOUND_DELAY: float = 0.3
const TEXT_DELAY: float = 1.0
const WIND_TEX = preload("res://assets/sprites/map/wind.png")

# ==================== 外部可调参数（Inspector） ====================
@export_range(30.0, 200.0) var wind_speed: float = 60.0
@export_range(2.0, 10.0) var wind_duration: float = 2.0
enum WindDir { 東, 西, 隨機 }
@export var wind_direction: WindDir = WindDir.東

# ==================== 内部状态变量 ====================
var _state: int = ZoneState.IDLE
var _player: Node2D = null
var _wind_timer: float = 0.0
var _stop_spawning: bool = false
var _sfx_player: AudioStreamPlayer = null
var _current_dir_sign: float = 1.0
var _trigger_enabled: bool = false

@onready var _wind_container: Node2D = get_node_or_null("CanvasLayer/WindParticles")
@onready var _label: Label = get_node_or_null("CanvasLayer/WindLabel")


# ==================== 初始化 ====================
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if _label:
		_label.visible = false
	add_to_group("boss_wind_zone")
	_auto_enable_if_needed()


func _auto_enable_if_needed() -> void:
	if _trigger_enabled:
		return
	var boss = get_tree().get_first_node_in_group("boss_2")
	if boss and boss.current_hp < boss.wind_hp_threshold:
		set_trigger_enabled(true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _state != ZoneState.IDLE:
		return
	if not _trigger_enabled:
		return
	_player = body
	_start_sequence()


# ==================== 刮风流程：音效→文字→风力 ====================
func _start_sequence() -> void:
	_state = ZoneState.WARNING

	if wind_direction == WindDir.隨機:
		_current_dir_sign = -1.0 if randf() > 0.5 else 1.0
	else:
		_current_dir_sign = 1.0 if wind_direction == WindDir.東 else -1.0
	if _label:
		_label.text = "風往東邊吹" if _current_dir_sign > 0 else "風往西邊吹"

	await get_tree().create_timer(SOUND_DELAY).timeout
	if _state != ZoneState.WARNING:
		return
	_sfx_player = AudioManager.play_sfx_fade_in(&"wind2", 1.5)

	await get_tree().create_timer(TEXT_DELAY - SOUND_DELAY).timeout
	if _state != ZoneState.WARNING:
		return
	if _label:
		_label.modulate.a = 1.0
		_label.visible = true
		var s_factor = (wind_speed - 30.0) / 170.0  # 0~1，风速越大闪越快
		var blink_half = 0.3 - s_factor * 0.25      # 风速30→0.3，200→0.05
		var text_time = 1.5 + (wind_duration - 2.0) / 8.0 * 2.5  # 时长2秒→1.5秒，10秒→4秒
		var tw_blink = create_tween()
		tw_blink.set_loops(ceili(text_time / (blink_half * 2)))
		tw_blink.tween_property(_label, "modulate:a", 0.0, blink_half)
		tw_blink.tween_property(_label, "modulate:a", 1.0, blink_half)

		await get_tree().create_timer(text_time).timeout
		if _state != ZoneState.WARNING:
			return
		_label.modulate.a = 1.0
		_label.visible = false
	_start_wind()


# ==================== 启动风力（持续生成风痕横穿屏幕） ====================
func _start_wind() -> void:
	_state = ZoneState.WIND
	_wind_timer = wind_duration
	_stop_spawning = false
	var screen = get_viewport().get_visible_rect().size
	var line_count = 6 + ceili((wind_speed - 30.0) / 170.0 * 14)  # 风速30→6条，200→20条
	for i in line_count:
		_spawn_wind_line(screen)


func _spawn_wind_line(screen: Vector2) -> void:
	if _state != ZoneState.WIND or _stop_spawning or not _wind_container:
		return
	var dir = _current_dir_sign
	var sprite = Sprite2D.new()
	sprite.texture = WIND_TEX
	sprite.modulate = Color(1, 1, 1, 1)
	var s = randf_range(0.3, 2.5)
	sprite.scale = Vector2(s, s)
	sprite.position.y = randf_range(-20, screen.y + 20)
	var speed = randf_range(400.0, 800.0)
	var travel = screen.x + 120
	var delay = randf_range(0, 0.3)
	if dir > 0:
		sprite.position.x = -60
		sprite.flip_h = false
	else:
		sprite.position.x = screen.x + 60
		sprite.flip_h = true
	_wind_container.add_child(sprite)
	var tw = create_tween()
	tw.tween_interval(delay)
	tw.tween_property(sprite, "position:x", sprite.position.x + dir * travel, travel / speed)
	tw.tween_callback(sprite.queue_free)
	tw.tween_callback(_spawn_wind_line.bind(screen))


func _physics_process(delta: float) -> void:
	if _state != ZoneState.WIND:
		return
	_wind_timer -= delta
	if _wind_timer <= 0.0:
		_end_wind()
		return
	if is_instance_valid(_player):
		_player.move_and_collide(Vector2(_current_dir_sign * wind_speed * delta, 0))


func _end_wind() -> void:
	_state = ZoneState.DONE
	if is_instance_valid(_sfx_player):
		AudioManager.stop_sfx_fade_out(_sfx_player, 1.5)
	_stop_spawning = true
	if _label:
		_label.visible = false


func _exit_tree() -> void:
	_end_wind()


func set_trigger_enabled(enabled: bool) -> void:
	_trigger_enabled = enabled


func force_stop() -> void:
	_trigger_enabled = false
	if _state != ZoneState.IDLE:
		_end_wind()
