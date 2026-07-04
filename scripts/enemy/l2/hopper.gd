extends CharacterBody2D
class_name Hopper

enum HopperState { HOP, CHASE, BOUNCE, JUMP, ROLL }

const PATROL_SPEED: float = 40.0
const HOP_INTERVAL: float = 0.35
const HOP_FORCE: float = -150.0
const CHASE_SPEED: float = 65.0
const BOUNCE_SPEED: float = 50.0
const BOUNCE_FORCE: float = -200.0
const PATROL_DISTANCE: float = 80.0
const GRAVITY: float = 980.0
const MAX_HP: int = 1
const DEATH_SOUND: StringName = &"disiwang"
const CHASE_DURATION: float = 3.0
const BOUNCE_DURATION: float = 2.0
const ROLL_DURATION: float = 0.4
const NORMAL_HEIGHT: float = 28.0
const ROLL_HEIGHT: float = 12.0
const NORMAL_POS_Y: float = 6.0


var _state: int = HopperState.HOP
var _is_dead: bool = false
var _current_hp: int
var _facing_right: bool = true
var _start_position: Vector2
var _hop_timer: float = 0.0
var _phase_timer: float = 0.0
var _roll_timer: float = 0.0
var _player_ref: Node2D = null
var _player_in_range: bool = false
var _jump_vy: float

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hurtbox_shape: CollisionShape2D = $HurtBox/CollisionShape2D
@onready var hitbox: Area2D = $HitBox
@onready var hitbox_shape: CollisionShape2D = $HitBox/CollisionShape2D
@onready var detect_range: Area2D = $DetectRange
@onready var floor_left: RayCast2D = $FloorDetectLeft
@onready var floor_right: RayCast2D = $FloorDetectRight


func _ready() -> void:
	_current_hp = MAX_HP
	_start_position = global_position
	add_to_group("fall_vulnerable")
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)
	if detect_range:
		detect_range.body_entered.connect(_on_player_entered)
		detect_range.body_exited.connect(_on_player_exited)
	anim.play("hop")


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match _state:
		HopperState.HOP:
			_update_hop(delta)
		HopperState.CHASE:
			_update_chase(delta)
		HopperState.BOUNCE:
			_update_bounce(delta)
		HopperState.JUMP:
			_update_jump(delta)
		HopperState.ROLL:
			_update_roll(delta)

	move_and_slide()

	if _state == HopperState.JUMP and is_on_floor():
		_set_state(HopperState.ROLL if _player_in_range else HopperState.HOP)


func _set_state(new_state: int) -> void:
	_state = new_state
	match _state:
		HopperState.HOP:
			anim.play("hop")
			_set_collision_height(NORMAL_HEIGHT, NORMAL_POS_Y)
			_start_position = global_position
		HopperState.CHASE:
			anim.play("roll")
			_adjust_collision_for_roll()
			_phase_timer = CHASE_DURATION
		HopperState.BOUNCE:
			anim.play("hop")
			_set_collision_height(NORMAL_HEIGHT, NORMAL_POS_Y)
			_phase_timer = BOUNCE_DURATION
		HopperState.JUMP:
			anim.play("jump")
			_set_collision_height(NORMAL_HEIGHT, NORMAL_POS_Y)
		HopperState.ROLL:
			anim.play("roll")
			_adjust_collision_for_roll()
			_roll_timer = ROLL_DURATION


func _set_collision_height(height: float, pos_y: float) -> void:
	var body_shape_res = body_shape.shape as RectangleShape2D
	var hurt_shape_res = hurtbox_shape.shape as RectangleShape2D
	var hit_shape_res = hitbox_shape.shape as RectangleShape2D
	if body_shape_res:
		body_shape_res.size.y = height
		body_shape.position.y = pos_y
	if hurt_shape_res:
		hurt_shape_res.size.y = height
		hurtbox_shape.position.y = pos_y
	if hit_shape_res:
		hit_shape_res.size.y = height
		hitbox_shape.position.y = pos_y



func _adjust_collision_for_roll() -> void:
	# 底部不动，只从上面缩
	var normal_bottom = NORMAL_POS_Y + NORMAL_HEIGHT / 2.0
	var roll_pos_y = normal_bottom - ROLL_HEIGHT / 2.0

	var body_shape_res = body_shape.shape as RectangleShape2D
	var hurt_shape_res = hurtbox_shape.shape as RectangleShape2D
	var hit_shape_res = hitbox_shape.shape as RectangleShape2D
	if body_shape_res:
		body_shape_res.size.y = ROLL_HEIGHT
		body_shape.position.y = roll_pos_y
	if hurt_shape_res:
		hurt_shape_res.size.y = ROLL_HEIGHT
		hurtbox_shape.position.y = roll_pos_y
	if hit_shape_res:
		hit_shape_res.size.y = ROLL_HEIGHT
		hitbox_shape.position.y = roll_pos_y


# ==================== 巡逻蹦跳 ====================

func _update_hop(_delta: float) -> void:
	_check_turn()
	_check_obstacle_jump()
	if _state != HopperState.HOP:
		return
	if is_on_floor() and _hop_timer <= 0.0:
		velocity.y = HOP_FORCE
		_hop_timer = HOP_INTERVAL
	_hop_timer -= get_physics_process_delta_time()
	velocity.x = PATROL_SPEED * (1.0 if _facing_right else -1.0)
	if _player_in_range:
		_set_state(HopperState.CHASE)


# ==================== 滚动追逐（3秒） ====================

func _update_chase(delta: float) -> void:
	_face_player()
	velocity.x = CHASE_SPEED * (1.0 if _facing_right else -1.0)
	_check_obstacle_jump()
	if _state != HopperState.CHASE:
		return
	if not _player_in_range:
		_set_state(HopperState.HOP)
		return
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_state(HopperState.BOUNCE)


# ==================== 蹦跳追逐（2秒） ====================

func _update_bounce(delta: float) -> void:
	_face_player()
	if is_on_floor() and _hop_timer <= 0.0:
		velocity.y = BOUNCE_FORCE
		_hop_timer = HOP_INTERVAL * 0.7
	_hop_timer -= delta
	velocity.x = BOUNCE_SPEED * (1.0 if _facing_right else -1.0)
	_check_obstacle_jump()
	if _state != HopperState.BOUNCE:
		return
	if not _player_in_range:
		_set_state(HopperState.HOP)
		return
	_phase_timer -= delta
	if _phase_timer <= 0.0:
		_set_state(HopperState.CHASE)


func _check_obstacle_jump() -> void:
	var floor_ray = floor_right if _facing_right else floor_left
	floor_ray.force_raycast_update()
	if is_on_wall() or not floor_ray.is_colliding():
		_calc_jump_vy()
		_set_state(HopperState.JUMP)
		velocity.y = _jump_vy


func _calc_jump_vy() -> void:
	if not _player_ref:
		_jump_vy = -320.0
		return

	var dist_x = abs(_player_ref.global_position.x - global_position.x)
	if dist_x < 50.0:
		dist_x = 50.0

	var t = dist_x / CHASE_SPEED
	t = clamp(t, 0.3, 1.2)

	var dy = _player_ref.global_position.y - global_position.y
	_jump_vy = (dy - 0.5 * GRAVITY * t * t) / t
	#此处调试跳跃高度
	_jump_vy = clamp(_jump_vy, -320.0, -150.0)


# ==================== 跳跃 ====================

func _update_jump(_delta: float) -> void:
	_face_player()
	velocity.x = CHASE_SPEED * (1.0 if _facing_right else -1.0)


# ==================== 滚动过渡 ====================

func _update_roll(delta: float) -> void:
	_roll_timer -= delta
	velocity.x = CHASE_SPEED * 0.5 * (1.0 if _facing_right else -1.0)
	if _roll_timer <= 0.0:
		if _player_in_range:
			_set_state(HopperState.CHASE)
		else:
			_set_state(HopperState.HOP)


# ==================== 方向与折返 ====================

func _check_turn() -> void:
	var travelled = global_position.x - _start_position.x
	if travelled > PATROL_DISTANCE and _facing_right:
		_facing_right = false
		anim.flip_h = true
		return
	if travelled < -PATROL_DISTANCE and not _facing_right:
		_facing_right = true
		anim.flip_h = false
		return
	var edge_ray = floor_right if _facing_right else floor_left
	edge_ray.force_raycast_update()
	if not edge_ray.is_colliding() or is_on_wall():
		_facing_right = not _facing_right
		anim.flip_h = not _facing_right


func _face_player() -> void:
	if not _player_ref:
		return
	var should_face_right = _player_ref.global_position.x > global_position.x
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		anim.flip_h = not _facing_right


# ==================== 玩家检测 ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref = body
	_player_in_range = true


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_player_ref = null
	_player_in_range = false


# ==================== 受伤死亡 ====================

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
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
