extends CharacterBody2D
class_name RisingNinja

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 2
## 巡逻速度（像素/秒）
@export var patrol_speed: float = 30.0
## 追击速度（像素/秒）
@export var chase_speed: float = 130.0
## 升龙击·水平速度（朝玩家方向，像素/秒）
@export var rise_horizontal_speed: float = 250.0
## 升龙击·水平减速（像素/秒²，先快后慢）
@export var rise_horizontal_decel: float = 400.0
## 升龙击·向上初速度（正数，同玩家剑术上挑 jump_force * 1.2）
@export var rise_vertical_force: float = 380.0
## 障碍物跳跃力
@export var jump_force: float = -450.0
## 追击范围（像素）
@export var chase_range: float = 200.0
## 前冲范围（像素，≤此值进入 charge 动画前冲）
@export var charge_range: float = 50.0
## 升龙范围（像素，≤此值释放 up 升龙击）
@export var attack_range: float = 25.0
## 接触伤害值
@export var contact_damage: int = 1
## 重力加速度
@export var gravity: float = 980.0
## 死亡动画名称
@export var death_anim: String = "death"
## 死亡音效 ID
@export var death_sound: StringName = &"disiwang"

# ==================== 节点引用 ====================

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect: RayCast2D = $WallDetect

# ==================== 状态枚举 ====================

enum State { PATROL, CHASE, CHARGE, OBSTACLE_JUMP, RISE, FALL }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1
var _state: int = State.PATROL
var _player_in_chase_range: bool = false
var _player_in_charge_range: bool = false
var _player_in_attack_range: bool = false


func _ready() -> void:
	current_hp = max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	hurtbox.took_damage.connect(_on_took_damage)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_update_player_detection()
	_face_player()

	match _state:
		State.PATROL:
			_update_patrol(delta)
		State.CHASE:
			_update_chase(delta)
		State.CHARGE:
			_update_charge(delta)
		State.OBSTACLE_JUMP:
			_update_obstacle_jump(delta)
		State.RISE:
			_update_rise(delta)
		State.FALL:
			_update_fall(delta)

	move_and_slide()

	# 落地检测
	if is_on_floor():
		match _state:
			State.RISE, State.FALL, State.OBSTACLE_JUMP:
				_on_landed()


# ==================== 玩家探测 ====================

func _update_player_detection() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_player_in_chase_range = false
		_player_in_charge_range = false
		_player_in_attack_range = false
		return

	var dist = abs(global_position.x - player.global_position.x)
	_player_in_chase_range = dist <= chase_range
	_player_in_charge_range = dist <= charge_range
	_player_in_attack_range = dist <= attack_range

	# PATROL 中发现玩家 → 转追击
	if _state == State.PATROL and _player_in_chase_range:
		_set_state(State.CHASE)


# ==================== 状态切换 ====================

func _set_state(new_state: int) -> void:
	_state = new_state
	match _state:
		State.PATROL:
			anim.play("walk")
		State.CHASE:
			anim.play("walk")
		State.CHARGE:
			anim.play("charge")
		State.OBSTACLE_JUMP:
			anim.play("jump")
		State.RISE:
			anim.play("up")
		State.FALL:
			anim.play("fall")


# ==================== PATROL 巡逻 ====================

func _update_patrol(_delta: float) -> void:
	_check_patrol_turn()
	velocity.x = patrol_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")


func _check_patrol_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	edge_ray.force_raycast_update()
	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)


# ==================== CHASE 追击 ====================

func _update_chase(_delta: float) -> void:
	if not _player_in_chase_range:
		# 丢失玩家 → 回巡逻
		_set_state(State.PATROL)
		return

	if _player_in_charge_range and is_on_floor():
		# 进入前冲范围 → charge 前冲
		_set_state(State.CHARGE)
		return

	# 检测前方障碍 → 翻越跳跃
	_check_obstacle_jump()

	velocity.x = chase_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")


# ==================== CHARGE 前冲 ====================

func _update_charge(_delta: float) -> void:
	if not _player_in_charge_range:
		# 超出前冲范围 → 回追击
		_set_state(State.CHASE)
		return

	if _player_in_attack_range and is_on_floor():
		# 进入升龙范围 → 释放升龙击
		_start_rise()
		return

	# charge 前冲，遇障碍依旧翻越
	_check_obstacle_jump()

	velocity.x = chase_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "charge":
		anim.play("charge")


# ==================== OBSTACLE_JUMP 翻越跳跃 ====================

func _check_obstacle_jump() -> void:
	var floor_ray = floor_detect_right if facing_right else floor_detect_left
	floor_ray.force_raycast_update()
	wall_detect.force_raycast_update()

	if is_on_wall() or (is_on_floor() and not floor_ray.is_colliding()):
		_set_state(State.OBSTACLE_JUMP)
		velocity.y = jump_force


func _update_obstacle_jump(_delta: float) -> void:
	velocity.x = chase_speed * (1.0 if facing_right else -1.0)


# ==================== RISE 升龙击 ====================

func _start_rise() -> void:
	_set_state(State.RISE)
	var dir = 1.0 if facing_right else -1.0
	# 同玩家 SwordUppercut：一次性水平初速度 + 向上初速度
	velocity.x = dir * rise_horizontal_speed
	velocity.y = -rise_vertical_force


func _update_rise(delta: float) -> void:
	# 水平：先快后慢（同 SwordUppercut）
	velocity.x = move_toward(velocity.x, 0, rise_horizontal_decel * delta)

	# 垂直：初速度已定，重力自然作用（同 SwordUppercut）
	# 开始下落 → 转 FALL
	if velocity.y > 0:
		_set_state(State.FALL)


# ==================== FALL 坠落 ====================

func _update_fall(_delta: float) -> void:
	if anim.animation != "fall":
		anim.play("fall")

	# 升龙击中间不再空中再升龙，落地后通过 _on_landed 判断


# ==================== 落地处理 ====================

func _on_landed() -> void:
	velocity.x = 0.0

	if _player_in_attack_range:
		# 落地后还在升龙范围 → 继续升龙
		_start_rise()
	elif _player_in_charge_range:
		# 在前冲范围 → charge
		_set_state(State.CHARGE)
	elif _player_in_chase_range:
		_set_state(State.CHASE)
	else:
		_set_state(State.PATROL)


# ==================== 方向 ====================

func _face_player() -> void:
	if _state == State.RISE or _state == State.FALL:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right
	wall_detect.target_position.x = 25.0 if right else -25.0


# ==================== 重力 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta


# ==================== 受击/死亡 ====================

func _on_took_damage(_damage: int, _is_heavy: bool) -> void:
	if is_dead:
		return

	current_hp -= 1
	if current_hp <= 0:
		_die()
		return

	AudioManager.play_sound(&"shoushang")


func _die() -> void:
	is_dead = true
	velocity = Vector2.ZERO
	set_physics_process(false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	anim.play(death_anim)
	AudioManager.play_sound(death_sound)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()
