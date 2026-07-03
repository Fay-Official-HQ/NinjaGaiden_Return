extends Area2D
class_name MonsterSoldierLaser

var _direction: float = 1.0
var _speed: float
var _hp: int = 1
var _death_sound: StringName = &"disiwang"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var enemy_hitbox: Area2D = $EnemyHitBox


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.animation_finished.connect(_on_death_finished)
	if hurt_box:
		hurt_box.took_damage.connect(_on_took_damage)


func initialize(dir: float, speed: float, angle_deg: float = 0.0) -> void:
	_direction = dir
	_speed = speed
	anim.flip_h = dir < 0
	rotation_degrees = angle_deg
	anim.play("flying")


func _process(delta: float) -> void:
	var movement = Vector2(_direction * _speed, 0.0).rotated(rotation)
	global_position += movement * delta


func _on_screen_exited() -> void:
	queue_free()


func _on_took_damage(_damage: int, _is_heavy: bool) -> void:
	_hp -= 1
	if _hp <= 0:
		AudioManager.play_sound(_death_sound)
		set_process(false)
		hurt_box.set_deferred("monitoring", false)
		hurt_box.set_deferred("monitorable", false)
		enemy_hitbox.set_deferred("monitoring", false)
		enemy_hitbox.set_deferred("monitorable", false)
		anim.play("death")


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
