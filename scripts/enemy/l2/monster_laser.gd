extends Area2D
class_name MonsterSoldierLaser

var _direction: Vector2 = Vector2.RIGHT
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


func initialize(direction: Vector2, speed: float) -> void:
	_direction = direction.normalized()
	_speed = speed
	anim.flip_h = _direction.x < 0
	rotation = _direction.angle()
	anim.play("flying")


func _process(delta: float) -> void:
	global_position += _direction * _speed * delta


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
