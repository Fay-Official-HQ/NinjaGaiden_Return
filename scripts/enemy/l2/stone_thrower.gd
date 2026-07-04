extends CharacterBody2D
class_name StoneThrower

enum ThrowerState { IDLE, THROW }

## 投石冷却时间（秒）
const ATTACK_COOLDOWN: float = 2.5
## 最大生命值
const MAX_HP: int = 1
## 死亡音效ID
const DEATH_SOUND: StringName = &"disiwang"
## 石头水平速度（像素/秒）
const STONE_SPEED: float = 180.0
## 石头上抛力度上限（负值=向上，绝对值越大抛越高）
const STONE_ARC: float = -400.0
## 重力加速度（像素/秒²）
const GRAVITY: float = 980.0

var _state: int = ThrowerState.IDLE
var _throw_cooldown: float = 0.0
var _is_dead: bool = false
var _current_hp: int
var _pending_throw: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detect_range: Area2D = $DetectRange
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

const STONE_SCENE = preload("res://scenes/enemy/l2/stone_projectile.tscn")


func _ready() -> void:
	_current_hp = MAX_HP
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)
	if detect_range:
		detect_range.body_entered.connect(_on_player_entered)
		detect_range.body_exited.connect(_on_player_exited)
	anim.frame_changed.connect(_on_throw_frame)
	anim.animation_finished.connect(_on_anim_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	_face_player()
	velocity.x = 0.0

	match _state:
		ThrowerState.IDLE:
			anim.play("idle")
		ThrowerState.THROW:
			_update_throw(delta)

	move_and_slide()


func _update_throw(delta: float) -> void:
	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0:
		_throw_cooldown = ATTACK_COOLDOWN
		_pending_throw = true
		anim.play("throw")


func _on_throw_frame() -> void:
	if _pending_throw and anim.animation == "throw" and anim.frame == 1:
		_spawn_stone()
		_pending_throw = false


func _on_anim_finished() -> void:
	if _is_dead:
		return
	if anim.animation == "throw":
		anim.play("idle")


func _spawn_stone() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir_x = 1.0 if player.global_position.x > global_position.x else -1.0
	var spawn_pos = global_position + Vector2(dir_x * 10, -10)
	var stone = STONE_SCENE.instantiate()
	stone.global_position = spawn_pos
	get_tree().current_scene.add_child(stone)

	var vx = dir_x * STONE_SPEED

	var dist_x = abs(spawn_pos.x - player.global_position.x)
	var t = dist_x / STONE_SPEED

	if t < 0.2:
		t = 0.2
	elif t > 2.5:
		t = 2.5

	var dy = player.global_position.y - spawn_pos.y
	var vy = (dy - 0.5 * GRAVITY * t * t) / t
	vy = clamp(vy, STONE_ARC, 100.0)

	stone.initialize(vx, vy)


func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = ThrowerState.THROW
	_throw_cooldown = 0.0


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = ThrowerState.IDLE


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	anim.flip_h = player.global_position.x > global_position.x


func _on_took_damage(damage: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_current_hp -= damage
	if _current_hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
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
