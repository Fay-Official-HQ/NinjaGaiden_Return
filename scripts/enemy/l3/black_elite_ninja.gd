extends CharacterBody2D
class_name BlackEliteNinja

## BlackEliteNinja —— 黑色精英忍者
## ============================================================
##  1. 平时左右巡逻（walk 动画）
##  2. 玩家进入 200px → 追击（walk 快速）
##  3. 玩家进入 100px → 随机攻击：跳斩 / 前冲 / 挥砍
##  4. 前冲/挥砍前有 0.3s 蓄力（xuli 动画）
##  5. SwordHitBox 只在特定攻击帧开启，跟随朝向翻转
## ============================================================

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 2
## 巡逻速度（像素/秒）
@export var patrol_speed: float = 30.0
## 巡逻范围（像素，0=无限制）
@export var patrol_range: float = 80.0
## 追击速度（像素/秒）
@export var chase_speed: float = 130.0
## 探测距离（像素）
@export var detect_range: float = 200.0
## 攻击距离（像素）
@export var attack_range: float = 100.0
## 攻击间隔（秒）
@export var attack_cooldown: float = 0.2
## 蓄力时长（秒）
@export var charge_duration: float = 0.5
## 前冲距离（像素）
@export var dash_distance: float = 100.0
## 前冲速度（像素/秒）
@export var dash_speed: float = 300.0
## 挥砍移动距离（像素）
@export var huikan_distance: float = 50.0
## 挥砍速度（像素/秒）
@export var huikan_speed: float = 200.0
## 跳斩·跳跃力
@export var jump_force: float = 400.0
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
@onready var sword_hitbox: Area2D = $SwordHitBox
@onready var sword_collision: CollisionShape2D = $SwordHitBox/CollisionShape2D
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect: RayCast2D = $WallDetect

# ==================== 状态枚举 ====================

enum State { PATROL, CHASE, CHARGE, DASH, HUIKAN, JUMP_RISE, JUMP_FALL }
enum AttackType { DASH, HUIKAN, JUMP_SLASH }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1

var _start_x: float = 0.0  # 初始生成 X 坐标（用于巡逻范围约束）

var _state: int = State.PATROL
var _attack_cd: float = 0.0
var _player_in_range: bool = false

# CHARGE
var _charge_timer: float = 0.0
var _charge_target: int = -1

# DASH
var _dash_start_x: float = 0.0
var _dash_dir: float = 1.0

# HUIKAN
var _huikan_start_x: float = 0.0
var _huikan_dir: float = 1.0
var _huikan_sword_on: bool = false

# JUMP_SLASH
var _jump_target_x: float = 0.0

var _flash_tween: Tween


func _ready() -> void:
	current_hp = max_hp
	_start_x = global_position.x

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	# SwordHitBox 默认关闭
	sword_hitbox.set_deferred("monitoring", false)

	# 信号连接
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	hurtbox.took_damage.connect(_on_took_damage)

	# 非循环动画确认
	anim.sprite_frames.set_animation_loop("huikan", false)

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
		State.DASH:
			_update_dash(delta)
		State.HUIKAN:
			_update_huikan(delta)
		State.JUMP_RISE:
			_update_jump_rise(delta)
		State.JUMP_FALL:
			_update_jump_fall(delta)

	move_and_slide()


# ==================== 玩家探测 ====================

func _update_player_detection() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		if _player_in_range:
			_player_in_range = false
			_on_player_exited_range()
		return

	var dist = abs(global_position.x - player.global_position.x)
	var was_in_range = _player_in_range
	_player_in_range = dist <= detect_range

	if _player_in_range and not was_in_range:
		_on_player_entered_range()
	elif not _player_in_range and was_in_range:
		_on_player_exited_range()


func _on_player_entered_range() -> void:
	if _state == State.PATROL:
		_state = State.CHASE
		_attack_cd = 0.0


func _on_player_exited_range() -> void:
	_exit_attack_state()
	_state = State.PATROL
	_attack_cd = 0.0


# ==================== 随机选择攻击 ====================

func _try_pick_attack() -> void:
	if is_dead or _attack_cd > 0.0:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = abs(global_position.x - player.global_position.x)
	if dist > attack_range:
		return

	var attacks = [AttackType.DASH, AttackType.HUIKAN, AttackType.JUMP_SLASH]
	var chosen = attacks[randi() % attacks.size()]

	match chosen:
		AttackType.DASH:
			_start_charge(AttackType.DASH)
		AttackType.HUIKAN:
			_start_charge(AttackType.HUIKAN)
		AttackType.JUMP_SLASH:
			_start_jump_slash()


# ==================== PATROL：巡逻 ====================

func _update_patrol(_delta: float) -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	var at_edge = not edge_ray.is_colliding()
	var at_wall = is_on_wall()

	# 巡逻范围限制（非零时生效）
	var out_of_range = false
	if patrol_range > 0.0:
		out_of_range = abs(global_position.x - _start_x) >= patrol_range

	# 碰到边缘、墙壁或超出巡逻范围 → 折返
	if at_edge or at_wall or out_of_range:
		_set_facing(not facing_right)

	velocity.x = patrol_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")


# ==================== CHASE：追击 ====================

func _update_chase(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_state = State.PATROL
		return

	velocity.x = chase_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")

	_attack_cd -= delta
	var dist = abs(global_position.x - player.global_position.x)
	if dist <= attack_range and _attack_cd <= 0.0:
		_try_pick_attack()


# ==================== CHARGE：蓄力（前冲/挥砍共用） ====================

func _start_charge(target: int) -> void:
	_state = State.CHARGE
	_charge_timer = charge_duration
	_charge_target = target
	velocity.x = 0.0
	velocity.y = 0.0
	_disable_sword()
	anim.play("xuli")


func _update_charge(delta: float) -> void:
	velocity.x = 0.0
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		match _charge_target:
			AttackType.DASH:
				_start_dash()
			AttackType.HUIKAN:
				_start_huikan()
		_charge_target = -1


# ==================== DASH：前冲 ====================

func _start_dash() -> void:
	_state = State.DASH
	_dash_start_x = global_position.x
	_dash_dir = 1.0 if facing_right else -1.0
	velocity.x = _dash_dir * dash_speed
	velocity.y = 0.0
	anim.play("dash")
	# 第一帧开启 SwordHitBox
	_enable_sword()


func _update_dash(_delta: float) -> void:
	var traveled = abs(global_position.x - _dash_start_x)
	if traveled >= dash_distance or is_on_wall():
		velocity.x = 0.0
		_disable_sword()
		_enter_chase_with_cd()


# ==================== HUIKAN：挥砍 ====================

func _start_huikan() -> void:
	_state = State.HUIKAN
	_huikan_start_x = global_position.x
	_huikan_dir = 1.0 if facing_right else -1.0
	_huikan_sword_on = false
	velocity.x = _huikan_dir * huikan_speed
	velocity.y = 0.0
	anim.play("huikan")
	# SwordHitBox 由 frame_changed 在第二帧开启


func _update_huikan(_delta: float) -> void:
	var traveled = abs(global_position.x - _huikan_start_x)
	if traveled >= huikan_distance or is_on_wall():
		velocity.x = 0.0
		_disable_sword()
		_enter_chase_with_cd()


# ==================== JUMP_SLASH：跳斩 ====================

func _start_jump_slash() -> void:
	_state = State.JUMP_RISE
	_disable_sword()

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_enter_chase()
		return

	_jump_target_x = player.global_position.x

	var dx = _jump_target_x - global_position.x
	var jump_time = 2.0 * jump_force / gravity
	velocity.x = dx / jump_time if jump_time > 0 else 0.0
	velocity.y = -jump_force

	anim.play("jump")


func _update_jump_rise(_delta: float) -> void:
	# 到达最高点 → 切换下落
	if velocity.y >= 0.0:
		_state = State.JUMP_FALL
		_enable_sword()
		anim.play("fall")


func _update_jump_fall(_delta: float) -> void:
	if is_on_floor():
		velocity.x = 0.0
		_disable_sword()
		_enter_chase_with_cd()


# ==================== SwordHitBox 管理 ====================

func _enable_sword() -> void:
	sword_hitbox.set_deferred("monitoring", true)


func _disable_sword() -> void:
	sword_hitbox.set_deferred("monitoring", false)


# ==================== 动画回调 ====================

func _on_frame_changed() -> void:
	# 挥砍第二帧（索引1）开启 SwordHitBox
	if anim.animation == "huikan" and anim.frame == 1 and not _huikan_sword_on:
		_huikan_sword_on = true
		_enable_sword()


func _on_anim_finished() -> void:
	if anim.animation == death_anim:
		queue_free()
		return
	if is_dead:
		return

	# huikan 播完主动结束
	if anim.animation == "huikan":
		velocity.x = 0.0
		_disable_sword()
		_enter_chase_with_cd()


# ==================== 面对玩家 ====================

func _face_player() -> void:
	if _state == State.PATROL:
		return
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != facing_right:
		_set_facing(should_face_right)


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right
	# SwordHitBox 同步翻转
	sword_collision.position.x = -sword_collision.position.x


# ==================== 状态切换工具 ====================

func _enter_chase() -> void:
	_state = State.CHASE
	velocity.x = 0.0
	anim.play("walk")


func _enter_chase_with_cd() -> void:
	_attack_cd = attack_cooldown
	_enter_chase()


func _exit_attack_state() -> void:
	_disable_sword()
	_charge_target = -1
	_huikan_sword_on = false
	velocity.x = 0.0


# ==================== 受伤/死亡 ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	current_hp -= amount
	AudioManager.play_sound(&"shoushang")
	_flash_white()
	if current_hp <= 0:
		_die()


func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(8.0, 8.0, 8.0, 1.0), 0.1)
	_flash_tween.tween_property(anim, "modulate", Color.WHITE, 0.2)


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(death_sound)

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	_disable_sword()
	set_physics_process(false)
	velocity = Vector2.ZERO

	if anim.sprite_frames and anim.sprite_frames.has_animation(death_anim):
		anim.play(death_anim)
	else:
		queue_free()


# ==================== 物理 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
