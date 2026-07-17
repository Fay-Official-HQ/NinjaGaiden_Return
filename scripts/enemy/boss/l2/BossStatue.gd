extends CharacterBody2D
class_name BossStatue

const MAX_HP := 3
const GRAVITY := 980.0

signal statue_destroyed(spawn_position: Vector2)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D

var _current_hp := MAX_HP
var _is_destroyed := false
var _flash_tween: Tween
var _locked_x: float


func _ready() -> void:
	_locked_x = global_position.x
	hurt_box.took_damage.connect(_on_statue_hit)
	animated_sprite.play("default")


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	global_position.x = _locked_x


func _on_statue_hit(_damage: int, _is_heavy: bool) -> void:
	if _is_destroyed:
		return

	_current_hp -= 1
	AudioManager.play_sound(&"shoushang")
	_flash_white()

	if _current_hp > 0:
		return

	_is_destroyed = true
	$HurtBox.monitoring = false
	$HurtBox.monitorable = false
	$HitBox.monitoring = false
	collision_shape.set_deferred("disabled", true)
	AudioManager.play_sound(&"disiwang")

	animated_sprite.play("death")
	await animated_sprite.animation_finished

	animated_sprite.play("isdead")
	await get_tree().create_timer(1.0).timeout

	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.TRANSPARENT, 1.0)
	await tween.finished

	statue_destroyed.emit(global_position)
	queue_free()


func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
