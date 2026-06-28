extends CanvasLayer
class_name BossDeathDirector

@onready var screen_fade_rect: ColorRect = $ScreenFadeRect

var _slash_scene: PackedScene = preload("res://scenes/effects/HorizontalSlash.tscn")
var _boss: Boss
var _is_playing: bool = false

var _boss_silhouette: Sprite2D
var _player_silhouette: Sprite2D
var _frozen_boss_tex: Texture2D
var _frozen_player_tex: Texture2D
var _frozen_boss_pos: Vector2
var _frozen_player_pos: Vector2
var _frozen_boss_flip: bool
var _frozen_player_flip: bool
var _frozen_canvas_transform: Transform2D

#定格时长
const FREEZE_DURATION: float = 1.2
#红光闪过时间点
const SLASH_DELAY: float = 0.7
const DEATH_ANIM_DURATION: float = 5.0
const FADE_OUT_DURATION: float = 3.0
const BLACK_HOLD_DURATION: float = 2.0
#下沉距离
const SINK_DISTANCE: float = 15.0


func _ready() -> void:
	screen_fade_rect.color = Color(1, 1, 1, 0)


func _capture_freeze_frame(boss: Boss) -> void:
	var viewport = boss.get_viewport()
	_frozen_canvas_transform = viewport.get_canvas_transform()

	if boss.animated_sprite and boss.animated_sprite.sprite_frames:
		_frozen_boss_tex = boss.animated_sprite.sprite_frames.get_frame_texture(
			boss.animated_sprite.animation, boss.animated_sprite.frame)
		_frozen_boss_pos = boss.global_position
		_frozen_boss_flip = boss.animated_sprite.flip_h

	var player = boss.player_ref
	if player and player.animated_sprite and player.animated_sprite.sprite_frames:
		_frozen_player_tex = player.animated_sprite.sprite_frames.get_frame_texture(
			player.animated_sprite.animation, player.animated_sprite.frame)
		_frozen_player_pos = player.global_position
		_frozen_player_flip = player.animated_sprite.flip_h


func _create_silhouettes() -> void:
	if _frozen_boss_tex:
		_boss_silhouette = Sprite2D.new()
		_boss_silhouette.texture = _frozen_boss_tex
		_boss_silhouette.flip_h = _frozen_boss_flip
		_boss_silhouette.centered = true
		_boss_silhouette.modulate = Color.BLACK
		_boss_silhouette.position = _frozen_canvas_transform * _frozen_boss_pos
		add_child(_boss_silhouette)

	if _frozen_player_tex:
		_player_silhouette = Sprite2D.new()
		_player_silhouette.texture = _frozen_player_tex
		_player_silhouette.flip_h = _frozen_player_flip
		_player_silhouette.centered = true
		_player_silhouette.modulate = Color.BLACK
		_player_silhouette.position = _frozen_canvas_transform * _frozen_player_pos
		add_child(_player_silhouette)


func _remove_silhouettes() -> void:
	if _boss_silhouette:
		_boss_silhouette.queue_free()
		_boss_silhouette = null
	if _player_silhouette:
		_player_silhouette.queue_free()
		_player_silhouette = null


func _spawn_slash() -> void:
	AudioManager.play_sound(&"chujue")
	var slash = _slash_scene.instantiate()
	slash.position = _frozen_canvas_transform * _boss.global_position
	add_child(slash)


func _disable_attack_hitboxes(boss: Boss) -> void:
	var attack_root = boss.get_node_or_null("AttackRoot")
	if attack_root:
		for child in attack_root.get_children():
			if child is Area2D:
				child.collision_layer = 0
				child.collision_mask = 0

func _safe_freeze_before_capture(boss: Boss) -> void:
	boss.is_dead = true
	boss.ignore_gravity = false
	boss.is_invincible = false
	boss.velocity = Vector2.ZERO


func play_death_sequence(boss: Boss) -> void:
	if _is_playing:
		return
	_is_playing = true
	AudioManager.fade_out_bgm(3.0)
	AudioManager.play_sound(&"dingling")
	_boss = boss

	boss.collision_layer = 0
	boss.collision_mask = 0
	_disable_attack_hitboxes(boss)

	_safe_freeze_before_capture(boss)
	_capture_freeze_frame(boss)

	screen_fade_rect.color = Color(1, 1, 1, 1)
	_create_silhouettes()

	boss.boss_ui.hide_with_animation()
	boss.visible = false
	if boss.player_ref:
		boss.player_ref.visible = false

	get_tree().create_timer(SLASH_DELAY, true, false, true).timeout.connect(
		func(): _spawn_slash(), CONNECT_ONE_SHOT)

	Engine.time_scale = 0.0

	get_tree().create_timer(FREEZE_DURATION, true, false, true).timeout.connect(
		_phase_recover, CONNECT_ONE_SHOT)


func _phase_recover() -> void:
	Engine.time_scale = 1.0

	_remove_silhouettes()

	_boss.die()
	if "ignore_gravity" in _boss:
		_boss.ignore_gravity = true

	_boss.visible = true
	if _boss.player_ref:
		_boss.player_ref.visible = true

	_boss.state_machine.change_state_by_name("BossDeathState", {"director": self})
	AudioManager.play_sound(&"bosssiwang")

	var sink_target_y = _boss.global_position.y + SINK_DISTANCE
	create_tween().tween_property(_boss, "global_position:y", sink_target_y, DEATH_ANIM_DURATION)

	screen_fade_rect.color = Color(1, 1, 1, 0)

	get_tree().create_timer(DEATH_ANIM_DURATION).timeout.connect(
		_phase_fade_out, CONNECT_ONE_SHOT)


func _phase_fade_out() -> void:
	create_tween().tween_property(screen_fade_rect, "color", Color(0, 0, 0, 1), FADE_OUT_DURATION)

	get_tree().create_timer(FADE_OUT_DURATION).timeout.connect(
		_phase_black_hold, CONNECT_ONE_SHOT)


func _phase_black_hold() -> void:
	get_tree().create_timer(BLACK_HOLD_DURATION).timeout.connect(
		_end_level, CONNECT_ONE_SHOT)








func _end_level() -> void:
	_is_playing = false

	if _boss:
		_boss.queue_free()
		_boss = null

	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	LevelManager.spawn_point = "default"

	get_tree().change_scene_to_file("res://scenes/ui/Cutscene.tscn")
