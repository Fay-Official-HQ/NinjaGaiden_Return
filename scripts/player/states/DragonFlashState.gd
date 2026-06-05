extends State
class_name DragonFlashState

const FADE_IN_TIME = 0.5
const FADE_OUT_TIME = 0.5
const SKILL_DURATION = 2.0
const WAVE_INTERVAL = 0.15
const SHADOWS_PER_WAVE = 3
const SHADOW_ACTIVE = 0.25
const SHADOW_FADE = 0.1
const SPREAD_X = 90.0
const SPREAD_Y = 30.0
const SPEED_MULTIPLIER = 0.5
const PLAYER_ALPHA = 0.0

var shadow_textures = [
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_1.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_2.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_3.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_4.png"),
	preload("res://assets/sprites/Ryu/shadows/shadow_pose_5.png")
]

var sprite: AnimatedSprite2D:
	get: return player.get_node("Visual/AnimatedSprite2D")
var shadow_container: Node2D:
	get: return player.get_node("ShadowContainer")

var _state = 0
var _timer = 0.0
var _wave_timer = 0.0
var _wave_count = 0
var _tween_fade: Tween = null

func enter(_msg: Dictionary = {}) -> void:
	_state = 0
	_timer = 0.0
	_wave_timer = 0.0
	player.is_invincible = true
	player.is_gravity_disabled = true

	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()

	_tween_fade = create_tween()
	_tween_fade.tween_property(sprite, "modulate:a", PLAYER_ALPHA, FADE_IN_TIME)

func update(_delta: float) -> void:
	match _state:
		0:
			_timer += _delta
			if _timer >= FADE_IN_TIME:
				_state = 1
				_timer = 0.0
			_wave_timer = WAVE_INTERVAL
			_wave_count = 0
		1:
			_timer += _delta
			_wave_timer += _delta
			if _wave_timer >= WAVE_INTERVAL:
				_wave_timer -= WAVE_INTERVAL
				spawn_wave()
			if _timer >= SKILL_DURATION:
				_state = 2
				_timer = 0.0
				if _tween_fade and _tween_fade.is_valid():
					_tween_fade.kill()
				_tween_fade = create_tween()
				_tween_fade.tween_property(sprite, "modulate:a", 1.0, FADE_OUT_TIME)
		2:
			_timer += _delta
			if _timer >= FADE_OUT_TIME:
				finish_skill()

func physics_update(_delta: float) -> void:
	player.velocity.y = 0
	var dir = player.input.move_direction
	player.velocity.x = dir * player.data.walk_speed * SPEED_MULTIPLIER
	if dir != 0:
		player.set_facing_direction(dir)
	player.move_and_slide()

func spawn_wave() -> void:
	_wave_count += 1
	for i in range(SHADOWS_PER_WAVE):
		create_shadow()
	if _wave_count % 3 == 0:
		trigger_screen_flash()

func create_shadow() -> void:
	var tex = shadow_textures[randi() % shadow_textures.size()]
	var s = Sprite2D.new()
	s.texture = tex
	s.modulate.a = randf_range(0.4, 0.7)
	s.scale.x = 1.0 if randf() > 0.5 else -1.0
	s.rotation = deg_to_rad(randf_range(-15, 15))
	s.scale *= randf_range(0.9, 1.1)
	shadow_container.add_child(s)
	s.global_position = player.global_position + Vector2(randf_range(-SPREAD_X, SPREAD_X), randf_range(-SPREAD_Y, SPREAD_Y))

	var tw = create_tween().set_parallel(false)
	tw.tween_interval(SHADOW_ACTIVE)
	tw.tween_property(s, "modulate:a", 0.0, SHADOW_FADE)
	tw.tween_callback(s.queue_free)

func trigger_screen_flash() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	player.get_tree().current_scene.add_child(canvas)

	var rect = ColorRect.new()
	rect.color = Color.WHITE
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(rect)

	var tw = create_tween()
	tw.tween_property(rect, "color:a", 0.0, 0.1)
	tw.tween_callback(canvas.queue_free)

func finish_skill() -> void:
	for child in shadow_container.get_children():
		child.queue_free()
	player.is_invincible = false
	player.is_gravity_disabled = false
	sprite.modulate.a = 1.0
	state_machine.change_state(player.fall_state, {"imbalance": false})

func exit() -> void:
	if _tween_fade and _tween_fade.is_valid():
		_tween_fade.kill()
	for child in shadow_container.get_children():
		child.queue_free()
	player.is_invincible = false
	player.is_gravity_disabled = false
	if sprite:
		sprite.modulate.a = 1.0
