# ============================================================
# Hopper_Monster（第四关敌人）
#
# 行为需求：
#   1. 待机：原地不动播放 idle 动画，始终面朝玩家
#   2. 玩家进入 250px 距离 → 以 hop 动画快速蹦跳追击，除非被杀死否则永不停歇
#   3. 玩家进入 80px 距离 → 跳跃攻击（JUMP_ATTACK）：起跳后固定朝玩家方向
#      跳约 80px（可能越过玩家），落地后玩家仍 ≤80px 则一直连跳（类似 chaser_green_ninja）
#   4. 遇到障碍物 → 跳跃追击（JUMP_CHASE）：与 hopper/chaser_monster 一样的
#      空中连跳翻越墙壁逻辑（_check_obstacle_jump / _calc_jump_vy / 空中撞墙连跳）
#   5. 死亡动画与音效和普通敌人一致（disiwang）
#   6. 跳跃状态（JUMP_ATTACK / JUMP_CHASE）开启 HurtBox2/HitBox2，
#      其他状态开启 HurtBox/HitBox
# ============================================================
extends CharacterBody2D
class_name HopperMonster

enum HopperState { IDLE, CHASE, JUMP_ATTACK, JUMP_CHASE }

# —— 待机 / 蹦跳追击 ——
const CHASE_RANGE: float = 250.0   # 开始追击的玩家距离（纯距离检测，无需 DetectRange 节点）
const CHASE_SPEED: float = 120.0   # 蹦跳追击水平速度
const HOP_FORCE: float = -230.0    # 追击蹦跳起跳力度
const HOP_INTERVAL: float = 0.3    # 追击蹦跳间隔（秒）
# —— 跳跃攻击（类似 chaser_green_ninja） ——
const JUMP_DISTANCE: float = 80.0   # 触发跳跃攻击的距离上限（玩家在 80px 内则一直连跳）
const JUMP_FORCE: float = -240.0    # 跳跃攻击起跳力度
const JUMP_SPEED_X: float = 163.3   # 跳跃水平速度 → 单次跳跃固定约 80px
# —— 跳跃追击（与 hopper/chaser_monster 一致） ——
const MAX_JUMP_COUNT: int = 6      # 空中撞墙连跳次数上限
# —— 通用 ——
const GRAVITY: float = 980.0
const MAX_HP: int = 1
const DEATH_SOUND: StringName = &"disiwang"


var _state: int = HopperState.IDLE
var _is_dead: bool = false
var _current_hp: int
var _facing_right: bool = true
var _hop_timer: float = 0.0
var _jump_vy: float
var _jump_count: int = 0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hurtbox2: Area2D = $HurtBox2
@onready var hitbox: Area2D = $HitBox
@onready var hitbox2: Area2D = $HitBox2
@onready var floor_left: RayCast2D = $FloorDetectLeft
@onready var floor_right: RayCast2D = $FloorDetectRight


func _ready() -> void:
	_current_hp = MAX_HP
	add_to_group("fall_vulnerable")
	if hurtbox:
		hurtbox.took_damage.connect(_on_took_damage)
		hurtbox2.took_damage.connect(_on_took_damage)
	_set_state(HopperState.IDLE)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	match _state:
		HopperState.IDLE:
			_update_idle(delta)
		HopperState.CHASE:
			_update_chase(delta)
		HopperState.JUMP_ATTACK:
			_update_jump_attack(delta)
		HopperState.JUMP_CHASE:
			_update_jump_chase(delta)

	move_and_slide()

	if (_state == HopperState.JUMP_ATTACK or _state == HopperState.JUMP_CHASE) and is_on_floor():
		_jump_count = 0
		if _state == HopperState.JUMP_ATTACK:
			# 落地后重新面朝玩家；若仍 ≤80px 则立即朝玩家连跳（chaser_green_ninja 行为）
			_face_player()
			if _is_player_in_jump_range():
				_do_jump_attack()
				return
		_set_state(HopperState.CHASE)


func _set_state(new_state: int) -> void:
	_state = new_state
	match _state:
		HopperState.IDLE:
			anim.play("idle")
			_switch_to_jump_hitboxes(false)
		HopperState.CHASE:
			anim.play("hop")
			_switch_to_jump_hitboxes(false)
		HopperState.JUMP_ATTACK:
			anim.play("jump")
			_switch_to_jump_hitboxes(true)
		HopperState.JUMP_CHASE:
			anim.play("jump")
			_switch_to_jump_hitboxes(true)


# 跳跃状态开启加高的 HurtBox2/HitBox2，其他状态开启 HurtBox/HitBox
func _switch_to_jump_hitboxes(jumping: bool) -> void:
	hurtbox.monitoring = not jumping
	hurtbox.monitorable = not jumping
	hurtbox2.monitoring = jumping
	hurtbox2.monitorable = jumping
	hitbox.monitoring = not jumping
	hitbox.monitorable = not jumping
	hitbox2.monitoring = jumping
	hitbox2.monitorable = jumping


# ==================== 待机（原地不动，始终面朝玩家） ====================

func _update_idle(_delta: float) -> void:
	_face_player()
	velocity.x = 0.0
	var player = _get_player()
	if player and global_position.distance_to(player.global_position) <= CHASE_RANGE:
		_set_state(HopperState.CHASE)


# ==================== 蹦跳追击（永不停止） ====================

func _update_chase(delta: float) -> void:
	_face_player()
	# 遇到障碍物 → 跳跃追击（翻越墙壁）
	_check_obstacle_jump()
	if _state != HopperState.CHASE:
		return

	var player = _get_player()
	# 玩家距离 ≤80px → 跳跃攻击（固定朝玩家方向跳约 80px，落地后仍 ≤80px 则一直连跳）
	if player and is_on_floor() and abs(player.global_position.x - global_position.x) <= JUMP_DISTANCE:
		_do_jump_attack()
		return

	# 快速蹦跳追击
	if is_on_floor() and _hop_timer <= 0.0:
		velocity.y = HOP_FORCE
		_hop_timer = HOP_INTERVAL
	_hop_timer -= delta
	velocity.x = CHASE_SPEED * (1.0 if _facing_right else -1.0)


# ==================== 跳跃攻击（类似 chaser_green_ninja） ====================

func _do_jump_attack() -> void:
	_jump_count = 1
	_set_state(HopperState.JUMP_ATTACK)
	velocity.y = JUMP_FORCE
	velocity.x = JUMP_SPEED_X * (1.0 if _facing_right else -1.0)


func _update_jump_attack(_delta: float) -> void:
	# 空中不面朝/不追踪玩家：起跳时方向已锁定，水平速度恒定 → 固定 80px 弧线
	velocity.x = JUMP_SPEED_X * (1.0 if _facing_right else -1.0)
	# 空中撞墙再跳（chaser_green_ninja 风格，固定力度，方向不变）
	if velocity.y >= 0 and is_on_wall() and _jump_count < MAX_JUMP_COUNT and not is_on_floor():
		_jump_count += 1
		velocity.y = JUMP_FORCE
		velocity.x = JUMP_SPEED_X * (1.0 if _facing_right else -1.0)


# ==================== 跳跃追击（障碍翻墙，与 hopper 保持一致，勿改动） ====================

func _check_obstacle_jump() -> void:
	var floor_ray = floor_right if _facing_right else floor_left
	floor_ray.force_raycast_update()
	if is_on_wall() or not floor_ray.is_colliding():
		_jump_count = 1
		_calc_jump_vy()
		_set_state(HopperState.JUMP_CHASE)
		velocity.y = _jump_vy


func _calc_jump_vy() -> void:
	var player = _get_player()
	if not player:
		_jump_vy = -320.0
		return

	var dist_x = abs(player.global_position.x - global_position.x)
	if dist_x < 50.0:
		dist_x = 50.0

	var t = dist_x / CHASE_SPEED
	t = clamp(t, 0.3, 1.2)

	var dy = player.global_position.y - global_position.y
	_jump_vy = (dy - 0.5 * GRAVITY * t * t) / t
	# 此处调试跳跃高度
	_jump_vy = clamp(_jump_vy, -320.0, -150.0)


func _update_jump_chase(_delta: float) -> void:
	_face_player()
	velocity.x = JUMP_SPEED_X * (1.0 if _facing_right else -1.0)
	# 空中撞墙连跳（hopper/chaser_monster 风格，瞄准玩家高度）
	if velocity.y >= 0 and is_on_wall() and _jump_count < MAX_JUMP_COUNT and not is_on_floor():
		_jump_count += 1
		_calc_jump_vy()
		velocity.y = _jump_vy


# ==================== 方向 ====================

func _face_player() -> void:
	var player = _get_player()
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != _facing_right:
		_facing_right = should_face_right
		anim.flip_h = not _facing_right


# ==================== 玩家获取与检测（纯距离检测） ====================

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player")


func _is_player_in_jump_range() -> bool:
	var player = _get_player()
	if not player:
		return false
	return abs(player.global_position.x - global_position.x) <= JUMP_DISTANCE


# ==================== 受伤死亡（与普通敌人一致） ====================

func _on_took_damage(damage: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_current_hp -= damage
	if _current_hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	for box in [hitbox, hitbox2, hurtbox, hurtbox2]:
		if box:
			box.set_deferred("monitoring", false)
			box.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
