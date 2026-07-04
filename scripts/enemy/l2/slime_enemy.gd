extends CharacterBody2D
class_name SlimeEnemy

const PATROL_SPEED_DEFAULT: float = 20.0
const PATROL_DISTANCE_DEFAULT: float = 80.0
const ATTACK_COOLDOWN_DEFAULT: float = 2.0
const PROJECTILE_SPEED_DEFAULT: float = 250.0
const MAX_HP_DEFAULT: int = 1
const WALL_PUSH: float = 30.0

enum SlimeState { PATROL, ATTACK }

## 巡逻移动速度（像素/秒）
@export var patrol_speed: float = PATROL_SPEED_DEFAULT
## 巡逻往返距离（像素，从出生点算起）
@export var patrol_distance: float = PATROL_DISTANCE_DEFAULT
## 攻击冷却时间（秒）
@export var attack_cooldown: float = ATTACK_COOLDOWN_DEFAULT
## 投射物飞行速度（像素/秒）
@export var projectile_speed: float = PROJECTILE_SPEED_DEFAULT
## 最大生命值
@export var max_hp: int = MAX_HP_DEFAULT

var _state: int = SlimeState.PATROL
var _patrol_dir: float = 1.0
var _wall_dir: float = 0.0
var _attached: bool = false
var _attack_timer: float = 0.0
var _is_dead: bool = false
var _current_hp: int
var _start_position: Vector2

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var wall_ray_left: RayCast2D = $WallDetectLeft
@onready var wall_ray_right: RayCast2D = $WallDetectRight
@onready var edge_ray_top: RayCast2D = $EdgeDetectTop
@onready var edge_ray_bottom: RayCast2D = $EdgeDetectBottom
@onready var attack_range: Area2D = $AttackRange
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

const LASER_SCENE = preload("res://scenes/enemy/l2/monster_laser.tscn")


func _ready() -> void:
	_current_hp = max_hp
	_start_position = global_position
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)
	_find_wall()
	anim.play("climb")


func _find_wall() -> void:
	wall_ray_left.force_raycast_update()
	wall_ray_right.force_raycast_update()

	var left_hit = wall_ray_left.is_colliding()
	var right_hit = wall_ray_right.is_colliding()

	if left_hit and not right_hit:
		_wall_dir = -1.0
		_attached = true
		anim.flip_h = true
	elif right_hit and not left_hit:
		_wall_dir = 1.0
		_attached = true
		anim.flip_h = false
	elif left_hit and right_hit:
		var left_dist = (wall_ray_left.get_collision_point() - global_position).length()
		var right_dist = (wall_ray_right.get_collision_point() - global_position).length()
		if left_dist < right_dist:
			_wall_dir = -1.0
			_attached = true
			anim.flip_h = true
		else:
			_wall_dir = 1.0
			_attached = true
			anim.flip_h = false
	else:
		_attached = false

	var edge_x = 24.0 * _wall_dir
	edge_ray_top.target_position.x = edge_x
	edge_ray_bottom.target_position.x = edge_x


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not _attached:
		_find_wall()
		if not _attached:
			velocity.y += 980.0 * delta
			move_and_slide()
			return

	if _attack_timer > 0.0:
		_attack_timer -= delta

	var player_in_range = _check_player_in_range()

	if player_in_range and _state == SlimeState.PATROL:
		_set_state(SlimeState.ATTACK)
	elif not player_in_range and _state == SlimeState.ATTACK:
		_set_state(SlimeState.PATROL)

	match _state:
		SlimeState.PATROL:
			_update_patrol()
		SlimeState.ATTACK:
			_update_attack()

	move_and_slide()


func _set_state(new_state: int) -> void:
	_state = new_state


func _update_patrol() -> void:
	velocity = Vector2(WALL_PUSH * _wall_dir, patrol_speed * _patrol_dir)
	_check_turn()
	_check_patrol_bounds()


func _check_turn() -> void:
	var edge_ray = edge_ray_bottom if _patrol_dir > 0 else edge_ray_top
	edge_ray.force_raycast_update()

	if not edge_ray.is_colliding():
		_patrol_dir *= -1.0
		return

	if _patrol_dir < 0 and is_on_ceiling():
		_patrol_dir = 1.0
	elif _patrol_dir > 0 and is_on_floor():
		_patrol_dir = -1.0


func _check_patrol_bounds() -> void:
	var travelled = global_position.y - _start_position.y
	if abs(travelled) >= patrol_distance:
		_patrol_dir = -1.0 if travelled > 0 else 1.0


func _update_attack() -> void:
	velocity = Vector2(WALL_PUSH * _wall_dir, patrol_speed * _patrol_dir)
	_check_turn()
	_check_patrol_bounds()
	if _attack_timer <= 0.0:
		_shoot_projectile()
		_attack_timer = attack_cooldown


func _check_player_in_range() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return attack_range.overlaps_body(player)


func _shoot_projectile() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = (player.global_position - global_position).normalized()
	var bullet = LASER_SCENE.instantiate()
	bullet.global_position = global_position + dir * 16.0
	get_tree().current_scene.add_child(bullet)

	if bullet.has_method("initialize"):
		bullet.initialize(dir, projectile_speed)


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
