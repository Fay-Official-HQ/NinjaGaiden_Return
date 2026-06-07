extends Area2D
class_name Item

enum ConsumableType { HEALTH, MP_SMALL, MP_LARGE }

@export var consumable_type: ConsumableType = ConsumableType.HEALTH
@export var restore_hp: int = 8
@export var restore_mp_small: int = 2
@export var restore_mp_large: int = 16
@export var float_flash_interval: float = 0.5
@export var fast_flash_duration: float = 3.0
@export var ground_wait_time: float = 5.0
@export var fall_gravity: float = 600.0

@export var show_texture: Texture2D
@export var hidden_texture: Texture2D

enum DropState { FLOATING, FALLING, GROUND_WAIT, FAST_FLASH }

var _state: DropState = DropState.FLOATING
var _velocity: Vector2 = Vector2.ZERO
var _state_timer: float = 0.0
var _flash_timer: float = 0.0
var _show_icon: bool = true

@onready var _sprite: Sprite2D = $Sprite
@onready var _pickup_area: Area2D = $PickupArea
@onready var _ground_detector: RayCast2D = $GroundDetector


func _ready() -> void:
	_sprite.texture = show_texture
	_pickup_area.body_entered.connect(_on_player_enter)


func receive_attack() -> void:
	if _state != DropState.FLOATING:
		return
	_state = DropState.FALLING
	_velocity = Vector2.ZERO
	_sprite.texture = show_texture
	_sprite.modulate = Color.WHITE


func _physics_process(delta: float) -> void:
	match _state:
		DropState.FLOATING:
			_handle_flash(delta, float_flash_interval)

		DropState.FALLING:
			_velocity.y += fall_gravity * delta
			position += _velocity * delta
			_ground_detector.force_raycast_update()
			if _ground_detector.is_colliding():
				var hit_point: Vector2 = _ground_detector.get_collision_point()
				var half_h: float = _sprite.texture.get_size().y / 2.0
				position.y = hit_point.y - half_h
				_state = DropState.GROUND_WAIT
				_state_timer = 0.0
				_velocity = Vector2.ZERO

		DropState.GROUND_WAIT:
			_state_timer += delta
			if _state_timer >= ground_wait_time:
				_state = DropState.FAST_FLASH
				_state_timer = 0.0
				_sprite.texture = show_texture
				_sprite.modulate = Color.WHITE

		DropState.FAST_FLASH:
			_state_timer += delta
			if _state_timer >= fast_flash_duration:
				queue_free()
				return
			var t: float = _state_timer / fast_flash_duration
			var alpha: float = 1.0 - t
			var blink: float = 1.0 if fmod(_state_timer * 8, 1.0) < 0.5 else 0.3
			_sprite.modulate = Color(1, 1, 1, alpha * blink)


func _handle_flash(delta: float, interval: float) -> void:
	_flash_timer += delta
	if _flash_timer >= interval:
		_flash_timer = 0.0
		_show_icon = not _show_icon
		_sprite.texture = show_texture if _show_icon else hidden_texture


func _on_player_enter(body: Node2D) -> void:
	if not (body is Player):
		return
	if _state == DropState.FLOATING:
		return
	_apply_effect(body)
	queue_free()


func _apply_effect(player: Player) -> void:
	match consumable_type:
		ConsumableType.HEALTH:
			player.current_hp = min(player.current_hp + restore_hp, player.data.max_hp)
		ConsumableType.MP_SMALL:
			player.ninjutsu.add_mp(restore_mp_small)
		ConsumableType.MP_LARGE:
			player.ninjutsu.add_mp(restore_mp_large)
