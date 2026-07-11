extends CharacterBody2D
class_name Spider

enum SpiderState { IDLE, FALL, RISE_SHOOT }

const PROJECTILE_SPEED_DEFAULT: float = 250.0
const MAX_HP_DEFAULT: int = 1
const RISE_SPEED: float = 200.0
const FALL_SPEED: float = 250.0
const ATTACK_COOLDOWN_DEFAULT: float = 2.0

## 是否为红色蜘蛛
@export var is_red: bool = false
## 投射物飞行速度（像素/秒）
@export var projectile_speed: float = PROJECTILE_SPEED_DEFAULT
## 最大生命值
@export var max_hp: int = MAX_HP_DEFAULT
## 发射子弹冷却时间（秒）
@export var attack_cooldown: float = ATTACK_COOLDOWN_DEFAULT
## 坠落速度（像素/秒）
@export var fall_speed: float = FALL_SPEED
## 上升速度（像素/秒）
@export var rise_speed: float = RISE_SPEED

var _state: int = SpiderState.IDLE
var _is_dead: bool = false
var _current_hp: int
var _attack_timer: float = 0.0
var _start_y: float = 0.0
var _delete_distance: float = 500.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var attack_range: Area2D = $AttackRange
@onready var fall_range: Area2D = $FallRange
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

const LASER_SCENE = preload("res://scenes/enemy/l2/monster_laser.tscn")


func _ready() -> void:
	_current_hp = max_hp
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)
	if is_red:
		anim.modulate = Color(1.0, 0.3, 0.2)
	anim.play("default")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	match _state:
		SpiderState.IDLE:
			_update_idle(delta)
			move_and_slide()
		SpiderState.FALL:
			_update_fall(delta)
		SpiderState.RISE_SHOOT:
			_update_rise_shoot(delta)


# ==================== IDLE：静止悬空 ====================

func _update_idle(delta: float) -> void:
	velocity = Vector2.ZERO

	if _attack_timer > 0.0:
		_attack_timer -= delta

	var player_in_fall = _check_player_in_fall_range()
	var player_in_attack = _check_player_in_attack_range()

	# FallRange → 触发坠落/上升
	if player_in_fall:
		if is_red:
			_enter_state(SpiderState.RISE_SHOOT)
			return
		else:
			_enter_state(SpiderState.FALL)
			return

	# AttackRange → 按冷却发射子弹
	if player_in_attack and _attack_timer <= 0.0:
		_shoot_projectile()
		_attack_timer = attack_cooldown
		anim.play("gongji")
	elif anim.animation == "gongji" and not anim.is_playing():
		anim.play("default")


# ==================== FALL：普通蜘蛛坠落到画面外 ====================

func _update_fall(delta: float) -> void:
	global_position.y += fall_speed * delta
	anim.play("fall")
	if global_position.y - _start_y > _delete_distance:
		queue_free()


# ==================== RISE_SHOOT：红色蜘蛛垂直上升 + 射击 ====================

func _update_rise_shoot(delta: float) -> void:
	global_position.y -= rise_speed * delta
	anim.play("gongji")
	if _start_y - global_position.y > _delete_distance:
		queue_free()


func _enter_state(new_state: int) -> void:
	_state = new_state
	_start_y = global_position.y
	match _state:
		SpiderState.FALL:
			velocity = Vector2.ZERO
		SpiderState.RISE_SHOOT:
			velocity = Vector2.ZERO
			_shoot_three_bullets()


func _shoot_three_bullets() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	AudioManager.play_sound(&"dandan")

	var base_dir = (player.global_position - global_position).normalized()
	var angles = [-25.0, 0.0, 25.0]

	for angle in angles:
		var bullet = LASER_SCENE.instantiate()
		bullet.global_position = global_position + base_dir * 16.0
		get_tree().current_scene.add_child(bullet)
		if bullet.has_method("initialize"):
			bullet.initialize(base_dir.rotated(deg_to_rad(angle)), projectile_speed)


func _shoot_projectile() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	AudioManager.play_sound(&"dandan")

	var dir = (player.global_position - global_position).normalized()
	var bullet = LASER_SCENE.instantiate()
	bullet.global_position = global_position + dir * 16.0
	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("initialize"):
		bullet.initialize(dir, projectile_speed)


func _check_player_in_attack_range() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return attack_range.overlaps_body(player)


func _check_player_in_fall_range() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return fall_range.overlaps_body(player)





func _on_took_damage(damage: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_current_hp -= damage
	if _current_hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(&"disiwang")
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	if anim.animation == "death":
		queue_free()
