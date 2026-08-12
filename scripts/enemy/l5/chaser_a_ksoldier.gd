extends BaseEnemy
class_name chaser_AKsoldier

## 跳跃初速度（像素/秒，向上为负），追击时碰到障碍/墙向上起跳
const JUMP_VELOCITY_Y: float = -300.0

## 士兵状态：追击（CHASE）/ 蓄力（CHARGE）/ 射击（SHOOT）
enum SoldierState { CHASE, CHARGE, SHOOT }

# ── 可调数据（Inspector 可调） ──
## 一轮射击的子弹数量（像步枪点射一样逐发连续射出）
@export var burst_count: int = 3
## 每发子弹之间的发射间隔（秒）
@export var burst_interval: float = 0.1

## 当前状态（初始为追击）
var _state: int = SoldierState.CHASE
## 蓄力剩余时间（秒），归零后进入射击
var _charge_timer: float = 0.0
## 与玩家的停止追击距离（像素），进入该距离内开始蓄力
var _stop_distance: float = 150.0

## 蓄力时长（秒），蓄力满后开始一轮点射
var _charge_duration: float = 0.5
## 追击移动速度（像素/秒）
var _chase_speed: float = 150.0
## 子弹飞行速度（像素/秒）
var _bullet_speed: float = 600.0
## 射击音效
var _shoot_sound: StringName = &"ak1"
## 死亡音效
var _death_sound: StringName = &"disiwang"
## 连续起跳次数（用于翻越障碍/贴墙连续跳跃的计数）
var _jump_count: int = 0

# ── 射击状态 ──
## 本轮已发射的子弹数量
var _burst_fired: int = 0
## 每发子弹之间的发射倒计时（秒）
var _burst_timer: float = 0.0
## 点射结束后的冷却倒计时（秒）
var _shoot_cooldown: float = 0.0

## 左侧地面检测射线（判定前方是否悬空，用于跳过坑洞）
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
## 右侧地面检测射线（判定前方是否悬空，用于跳过坑洞）
@onready var floor_detect_right: RayCast2D = $FloorDetectRight


func _ready() -> void:
	super()
	current_hp = 1
	_face_player()
	anim.play("run")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += 980.0 * delta

	match _state:
		SoldierState.CHASE:
			_update_chase(delta)
		SoldierState.CHARGE:
			_update_charge(delta)
		SoldierState.SHOOT:
			_update_shoot(delta)

	move_and_slide()

	if is_on_floor():
		_jump_count = 0


func _update_chase(_delta: float) -> void:
	_face_player()
	anim.play("run")

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist_x = abs(player.global_position.x - global_position.x)
	if dist_x <= _stop_distance:
		_state = SoldierState.CHARGE
		_charge_timer = _charge_duration
		return

	velocity.x = _chase_speed * (1.0 if facing_right else -1.0)

	if _should_jump_obstacle():
		velocity.y = JUMP_VELOCITY_Y

	if not is_on_floor() and is_on_wall() and _jump_count < 6 and velocity.y >= 0:
		_jump_count += 1
		velocity.y = JUMP_VELOCITY_Y


func _should_jump_obstacle() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall():
		_jump_count = 1
		return true
	var floor_ray = floor_detect_right if facing_right else floor_detect_left
	floor_ray.force_raycast_update()
	if not floor_ray.is_colliding():
		_jump_count = 1
		return true
	return false


func _update_charge(delta: float) -> void:
	_face_player()
	velocity.x = 0.0
	anim.play("idle")

	# 玩家跑远了就回去追
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist_x = abs(player.global_position.x - global_position.x)
		if dist_x > _stop_distance * 1.5:
			_state = SoldierState.CHASE
			return

	_charge_timer -= delta
	if _charge_timer <= 0.0:
		anim.modulate = Color.WHITE
		_state = SoldierState.SHOOT
		_burst_fired = 0
		_burst_timer = 0.0  # 进入射击立即打出第一发


func _update_shoot(delta: float) -> void:
	_face_player()
	velocity.x = 0.0

	# 玩家跑远了就回去追
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist_x = abs(player.global_position.x - global_position.x)
		if dist_x > _stop_distance * 1.5:
			_state = SoldierState.CHASE
			_burst_fired = 0
			return

	if _burst_fired < burst_count:
		# 一轮点射：按间隔逐发连续发射
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			_burst_timer = burst_interval
			_burst_fired += 1
			AudioManager.play_sound(_shoot_sound)
			_shoot_bullet()
			anim.play("shoot")
	else:
		# 本轮点射结束，进入冷却后回到蓄力
		_shoot_cooldown -= delta
		if _shoot_cooldown <= 0.0:
			_burst_fired = 0
			_state = SoldierState.CHARGE
			_charge_timer = _charge_duration


## 朝前方发射 1 发子弹
func _shoot_bullet() -> void:
	var bullet_scene = preload("res://scenes/enemy/l5/soldier_bullet2.tscn")
	var dir = 1.0 if facing_right else -1.0
	var origin = global_position + Vector2(14 * dir, -5)

	var bullet = bullet_scene.instantiate()
	bullet.global_position = origin
	get_tree().current_scene.add_child(bullet)
	bullet.initialize(dir, _bullet_speed)


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(_death_sound)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
