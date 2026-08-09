extends Area2D
class_name MechBat

## ============================================================
##  MechBat —— 机械蝙蝠（去数据驱动版）
##  数据直接写在代码中，所有参数均已导出，方便调试时在
##  Inspector 中直接修改观察效果。
## ============================================================

# ----- 调试参数（Inspector 中可直接修改） -----
@export var max_hp: int = 1                    # 生命值
@export var move_speed: float = 60.0           # 水平移动速度（像素/秒）
@export var sine_amplitude: float = 30.0       # 正弦摆动幅度（像素）
@export var sine_frequency: float = 1.0        # 正弦摆动频率（周期/秒）
@export var contact_damage: int = 1            # 接触伤害（预留）
@export var death_anim: String = "death"       # 死亡动画名称
@export var facing_right: bool = false          # 初始朝向（右）
@export var death_sound: StringName = &"disiwang" # 死亡音效ID

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

var is_dead: bool = false
var start_y: float
var time: float = 0.0
var current_hp: int = 1


func _ready() -> void:
	start_y = global_position.y
	current_hp = max_hp
	_set_facing(facing_right)
	anim.play("fly")

	hurtbox.took_damage.connect(_on_took_damage)


func _process(delta: float) -> void:
	if is_dead:
		return

	var direction = 1.0 if facing_right else -1.0
	position.x += move_speed * direction * delta

	time += delta
	var offset_y = sin(time * sine_frequency * TAU) * sine_amplitude
	position.y = start_y + offset_y

	_check_far_away()


func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()


func _die() -> void:
	is_dead = true

	AudioManager.play_sound(death_sound)

	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)

	set_process(false)

	anim.play(death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _check_far_away() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var half_view = get_viewport().get_visible_rect().size * 0.5
	var limit_x = half_view.x + 300.0
	var limit_y = half_view.y + 300.0
	if abs(global_position.x - cam.global_position.x) > limit_x or abs(global_position.y - cam.global_position.y) > limit_y:
		queue_free()


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right
