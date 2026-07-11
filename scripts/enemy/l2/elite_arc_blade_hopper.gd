# res://scripts/enemy/l2/elite_arc_blade_hopper.gd
# 精英弧刃跳跃者：追击玩家、弧线跳跃投掷落刃、狂暴隐身+平抛
extends BaseEnemy
class_name Elite_ArcBladeHopper

enum HopperState { PATROL, CHASE, ARC_JUMP }

@onready var detect_range: Area2D = $DetectRange
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight

## 精英怪血量
@export var elite_max_hp: int = 2
## 巡逻速度
@export var patrol_speed: float = 30.0
## 追击速度
@export var chase_speed: float = 150.0
## 触发弧跳的玩家距离
@export var arc_distance: float = 130.0
## 跳跃力度(负值越大跳越高)
@export var jump_force: float = -500.0
## 跳跃水平速度倍率，越大跳得越远
@export var jump_horizontal_mult: float = 1.0
## 落刃间隔(秒)
@export var blade_drop_interval: float = 0.25
## 狂暴期间落刃间隔(秒)
@export var rage_blade_drop_interval: float = 0.2
## 落刃下落速度
@export var blade_speed: float = 400.0
## 狂暴持续时长(秒)
@export var rage_duration: float = 3.0
## 碰撞伤害
@export var contact_damage: int = 1

var _state: int = HopperState.PATROL
var _start_position: Vector2
var _move_dir: float = 1.0
var _blade_timer: float = 0.0
var _is_raging: bool = false
var _rage_time_left: float = 0.0


const BLADE_SCENE = preload("res://scenes/enemy/l2/blade.tscn")


func _ready() -> void:
	super()
	_start_position = global_position
	current_hp = elite_max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage
	hitbox.collision_mask = 1
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if _is_raging:
		_rage_time_left -= delta
		var elapsed = rage_duration - _rage_time_left
		if elapsed < 1.0:
			anim.modulate.a = 1.0 - elapsed
		elif elapsed < 2.0:
			anim.modulate.a = 0.0
		else:
			anim.modulate.a = (elapsed - 2.0)
		if _rage_time_left <= 0.0:
			_exit_rage()

	_apply_gravity(delta)

	match _state:
		HopperState.PATROL:
			_update_patrol(delta)
		HopperState.CHASE:
			_update_chase(delta)
		HopperState.ARC_JUMP:
			_update_arc_jump(delta)

	move_and_slide()


# ==================== 工具方法 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


func _drop_blade() -> void:
	AudioManager.play_sound(&"luoren")
	var blade = BLADE_SCENE.instantiate()
	blade.global_position = global_position + Vector2(0, 16)
	get_tree().current_scene.add_child(blade)
	if blade.has_method("initialize"):
		blade.initialize(Vector2.DOWN, blade_speed)


# ==================== PATROL ====================

func _update_patrol(_delta: float) -> void:
	anim.play("idle")
	_check_patrol_turn()
	_set_facing(_move_dir > 0)
	velocity.x = patrol_speed * _move_dir


func _check_patrol_turn() -> void:
	var edge_ray = floor_detect_right if _move_dir > 0 else floor_detect_left
	if not edge_ray.is_colliding() or is_on_wall():
		_move_dir *= -1.0
		return

	var distance = global_position.x - _start_position.x
	if _move_dir > 0 and distance > 80.0:
		_move_dir = -1.0
	elif _move_dir < 0 and distance < -80.0:
		_move_dir = 1.0


# ==================== CHASE ====================

func _update_chase(_delta: float) -> void:
	_face_player()
	anim.play("idle")

	var player = _get_player()
	if not player:
		_state = HopperState.PATROL
		return

	var dx = player.global_position.x - global_position.x
	var dist = abs(dx)

	if dist <= arc_distance and is_on_floor():
		_start_arc_jump(player, dx)
		return

	velocity.x = chase_speed * (1.0 if dx > 0 else -1.0)


func _start_arc_jump(player: Node2D, dx: float) -> void:
	_state = HopperState.ARC_JUMP
	_face_player()
	_blade_timer = 0.0

	var dir_sign = 1.0 if dx > 0 else -1.0
	var target_x = player.global_position.x + abs(dx) * dir_sign

	var travel_x = target_x - global_position.x
	velocity.x = travel_x * jump_horizontal_mult
	velocity.y = jump_force

	anim.play("jump")


# ==================== ARC_JUMP ====================

func _update_arc_jump(delta: float) -> void:
	_face_player()

	var drop_interval = rage_blade_drop_interval if _is_raging else blade_drop_interval
	_blade_timer += delta
	if _blade_timer >= drop_interval:
		_blade_timer -= drop_interval
		_drop_blade()

	if is_on_floor():
		_on_arc_landed()
	elif is_on_wall():
		_state = HopperState.CHASE
		anim.play("idle")


## 弧跳落地：检查玩家是否在范围内，是则连跳
func _on_arc_landed() -> void:
	var player = _get_player()
	if player:
		var dx = player.global_position.x - global_position.x
		if abs(dx) <= arc_distance:
			_start_arc_jump(player, dx)
			return

	_state = HopperState.CHASE
	anim.play("idle")


# ==================== 碰撞/跳跃辅助 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta


# ==================== 玩家检测 ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _state == HopperState.PATROL:
		_state = HopperState.CHASE


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _state == HopperState.CHASE or _state == HopperState.ARC_JUMP:
		_state = HopperState.PATROL


# ==================== 受击/狂暴 ====================

func _reapply_hurtbox() -> void:
	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)

func _exit_rage() -> void:
	_is_raging = false
	anim.modulate.a = 1.0
	_reapply_hurtbox()

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	if _is_raging:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()
		return
	AudioManager.play_sound(&"shoushang")
	if current_hp <= 1 and not _is_raging:
		_start_rage()


func _start_rage() -> void:
	_is_raging = true
	_rage_time_left = rage_duration
	anim.modulate.a = 0.0
	anim.play("yinshen")

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(&"disiwang")
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()
