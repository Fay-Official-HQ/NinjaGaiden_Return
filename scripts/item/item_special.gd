extends Area2D
class_name ItemSpecial

@export var fast_flash_duration: float = 3.0
@export var ground_wait_time: float = 5.0
@export var fall_gravity: float = 600.0

enum DropState { FLOATING, FALLING, GROUND_WAIT, FAST_FLASH }

var _state: DropState = DropState.FLOATING
var _velocity: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _consumed: bool = false

@onready var _anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var _pickup_area: Area2D = $PickupArea
@onready var _ground_detector: RayCast2D = $GroundDetector


func _ready() -> void:
	_pickup_area.body_entered.connect(_on_player_enter)
	_anim.play("default")


func receive_attack() -> void:
	if _state != DropState.FLOATING:
		return
	_state = DropState.FALLING
	_velocity = Vector2.ZERO
	_anim.play("fall")
	_anim.modulate = Color.WHITE
	set_deferred("monitoring", false)

	for body in _pickup_area.get_overlapping_bodies():
		if body is Player:
			_consumed = true
			_apply_effect(body)
			return


func _physics_process(delta: float) -> void:
	if _consumed:
		return
	match _state:
		DropState.FLOATING:
			pass

		DropState.FALLING:
			_velocity.y += fall_gravity * delta
			position += _velocity * delta
			_ground_detector.force_raycast_update()
			if _ground_detector.is_colliding():
				var tex = _anim.sprite_frames.get_frame_texture("fall", 0)
				var half_h = tex.get_size().y / 2.0 if tex else 8.0
				position.y = _ground_detector.get_collision_point().y - half_h
				_state = DropState.GROUND_WAIT
				_state_timer = 0.0
				_velocity = Vector2.ZERO

		DropState.GROUND_WAIT:
			_state_timer += delta
			if _state_timer >= ground_wait_time:
				_state = DropState.FAST_FLASH
				_state_timer = 0.0
				_anim.modulate = Color.WHITE

		DropState.FAST_FLASH:
			_state_timer += delta
			if _state_timer >= fast_flash_duration:
				queue_free()
				return
			var t: float = _state_timer / fast_flash_duration
			var alpha: float = 1.0 - t
			var blink: float = 1.0 if fmod(_state_timer * 8, 1.0) < 0.5 else 0.3
			_anim.modulate = Color(1, 1, 1, alpha * blink)


func _on_player_enter(body: Node2D) -> void:
	if _consumed:
		return
	if not (body is Player):
		return
	if _state == DropState.FLOATING:
		return
	_consumed = true
	_apply_effect(body)


func _apply_effect(player: Player) -> void:
	AudioManager.play_sound(&"HPhuifu")

	global_position = player.global_position
	_anim.stop()
	_anim.frame = 0
	_anim.position = Vector2(0, 0)
	_anim.modulate = Color(1, 1, 1, 0.7)
	_anim.scale = Vector2(0.8 * player.facing_direction, 0.8)
	_anim.z_index = 1
	_anim.play("wuye")

	var frames = _anim.sprite_frames
	var fc = frames.get_frame_count("wuye")
	var anim_len: float = 0.0
	for i in fc:
		anim_len += frames.get_frame_duration("wuye", i)
	anim_len /= frames.get_animation_speed("wuye")

	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(_anim, "position:y", -60, anim_len)
	tween.tween_property(_anim, "modulate:a", 0.0, anim_len)
	tween.tween_property(_anim, "scale", Vector2(1.1 * player.facing_direction, 1.1), anim_len)
	tween.finished.connect(queue_free, CONNECT_ONE_SHOT)

	player.special_invincible_timer = 5.0
