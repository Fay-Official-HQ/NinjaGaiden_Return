extends Area2D
class_name BatEnemy

@export var data: BatData

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var is_dead: bool = false
var facing_right: bool = true
var start_y: float
var time: float = 0.0
var current_hp: int = 1


func _ready() -> void:
	start_y = global_position.y
	facing_right = data.facing_right
	current_hp = data.max_hp
	_set_facing(facing_right)
	anim.play("fly")

	hurtbox.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)


func _process(delta: float) -> void:
	if is_dead:
		return

	var direction = 1.0 if facing_right else -1.0
	position.x += data.move_speed * direction * delta

	time += delta
	var offset_y = sin(time * data.sine_frequency * TAU) * data.sine_amplitude
	position.y = start_y + offset_y


func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()


func _die() -> void:
	is_dead = true

	AudioManager.play_sound(data.death_sound)

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)

	set_process(false)

	anim.play(data.death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _on_screen_exited() -> void:
	if not is_dead:
		queue_free()


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right
