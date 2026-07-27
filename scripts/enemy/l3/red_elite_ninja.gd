extends CharacterBody2D
class_name RedEliteNinja

## RedEliteNinja —— 红色精英忍者（第三关最强忍者）
## ============================================================
##  1. 静止待机，不巡逻
##  2. 玩家进入 200px → 跳跃追击（jump 动画，50~100px 随机距离）
##  3. 玩家进入 100px → 随机攻击：扔炸弹 / 前冲 / 跳跃轰炸
##  4. SwordHitBox 仅在前冲时开启，跟随朝向翻转
## ============================================================

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 3
## 追击跳跃力（控制跳跃高度）
@export var chase_jump_force: float = 320.0
## 跳跃轰炸·跳跃力（比追击更高，-450左右）
@export var bomb_jump_force: float = 450.0
## 追击跳跃最小距离（像素）
@export var chase_jump_min: float = 80.0
## 追击跳跃最大距离（像素）
@export var chase_jump_max: float = 120.0
## 探测距离（像素）
@export var detect_range: float = 200.0
## 攻击距离（像素）
@export var attack_range: float = 100.0
## 攻击间隔（秒）
@export var attack_cooldown: float = 0.3
## 蓄力时长（秒）
@export var charge_duration: float = 0.3
## 前冲距离（像素）
@export var dash_distance: float = 100.0
## 前冲速度（像素/秒）
@export var dash_speed: float = 300.0
## 炸弹飞行速度（像素/秒）
@export var bomb_speed: float = 500.0
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

# ==================== 状态枚举 ====================

enum State { APPEARING, IDLE, CHASE, THROW_BOMB, CHARGE, DASH, BOMB_JUMP_RISE, BOMB_JUMP_FALL }
enum AttackType { THROW, DASH, BOMB_JUMP }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1

var _state: int = State.IDLE
var _attack_cd: float = 0.0
var _player_in_range: bool = false

# CHARGE
var _charge_timer: float = 0.0
var _charge_target: int = -1

# DASH
var _dash_start_x: float = 0.0
var _dash_dir: float = 1.0

# BOMB_JUMP (无额外状态变量)


var _flash_tween: Tween


func _ready() -> void:
	current_hp = max_hp

	# SwordHitBox 默认关闭（伤害已在场景中设置为 2）
	sword_hitbox.set_deferred("monitoring", false)

	# 信号连接
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	hurtbox.took_damage.connect(_on_took_damage)

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 显现状态：只受重力，不做任何 AI 逻辑和玩家探测
	if _state == State.APPEARING:
		_apply_gravity(delta)
		move_and_slide()
		return

	_apply_gravity(delta)
	_update_player_detection()
	_face_player()

	match _state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase(delta)
		State.THROW_BOMB:
			_update_throw_bomb()
		State.CHARGE:
			_update_charge(delta)
		State.DASH:
			_update_dash()
		State.BOMB_JUMP_RISE:
			_update_bomb_jump_rise()
		State.BOMB_JUMP_FALL:
			_update_bomb_jump_fall()

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
	if _state == State.IDLE:
		_state = State.CHASE
		_attack_cd = 0.0
		# 直接开始追击跳跃
		_do_chase_jump()


func _on_player_exited_range() -> void:
	# 红色精英忍者一旦追击就不会丢失目标，始终保持追击
	# 只有死亡才能停止
	pass


# ==================== 随机选择攻击 ====================

func _try_pick_attack() -> void:
	if is_dead or not is_on_floor() or _attack_cd > 0.0:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = abs(global_position.x - player.global_position.x)
	if dist > attack_range:
		return

	var attacks = [AttackType.THROW, AttackType.DASH, AttackType.BOMB_JUMP]
	var chosen = attacks[randi() % attacks.size()]

	match chosen:
		AttackType.THROW:
			_start_throw_bomb()
		AttackType.DASH:
			_start_charge(AttackType.DASH)
		AttackType.BOMB_JUMP:
			_start_bomb_jump()


# ==================== IDLE：待机 ====================

func _update_idle() -> void:
	velocity.x = 0.0
	if anim.animation != "idle":
		anim.play("idle")


# ==================== CHASE：跳跃追击 ====================

func _do_chase_jump() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dir = 1.0 if player.global_position.x > global_position.x else -1.0
	var jump_dist = chase_jump_min + randf() * (chase_jump_max - chase_jump_min)
	var target_x = global_position.x + dir * jump_dist

	# 计算抛物线初速度
	var dx = target_x - global_position.x
	var jump_time = 2.0 * chase_jump_force / gravity
	if jump_time > 0:
		velocity.x = dx / jump_time
	else:
		velocity.x = 0.0
	velocity.y = -chase_jump_force

	anim.play("jump")


func _update_chase(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_state = State.IDLE
		return

	# 落地时判断
	if is_on_floor():
		var dist = abs(global_position.x - player.global_position.x)
		if dist <= attack_range:
			_try_pick_attack()
		else:
			# 继续追击跳跃
			_do_chase_jump()

	_attack_cd -= delta


# ==================== THROW_BOMB：扔炸弹 ====================

func _start_throw_bomb() -> void:
	_state = State.THROW_BOMB
	velocity.x = 0.0
	_disable_sword()
	anim.play("throw")
	# 炸弹在第二帧（frame_changed → frame == 1）扔出


func _update_throw_bomb() -> void:
	velocity.x = 0.0


func _do_throw_bomb() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_enter_chase()
		return

	var dir = (player.global_position - global_position).normalized()
	var dart = preload("res://scenes/enemy/l3/FireDart.tscn").instantiate() as BombDart
	dart.initialize(dir, bomb_speed)
	dart.global_position = global_position + dir * 16 + Vector2(0, 0)
	get_tree().current_scene.add_child(dart)

	AudioManager.play_sound(&"shibingfashe")


# ==================== CHARGE：蓄力 ====================

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


func _update_dash() -> void:
	var traveled = abs(global_position.x - _dash_start_x)
	if traveled >= dash_distance or is_on_wall():
		velocity.x = 0.0
		_disable_sword()
		_enter_chase_with_cd()


# ==================== BOMB_JUMP：跳跃轰炸 ====================

func _start_bomb_jump() -> void:
	_state = State.BOMB_JUMP_RISE
	_disable_sword()

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_enter_chase()
		return

	# 对称位置：以玩家位置为锚点，跳跃到另一侧
	var dx = player.global_position.x - global_position.x
	var target_x = player.global_position.x + dx

	var travel_x = target_x - global_position.x
	var jump_time = 2.0 * bomb_jump_force / gravity
	if jump_time > 0:
		velocity.x = travel_x / jump_time
	else:
		velocity.x = 0.0
	velocity.y = -bomb_jump_force

	anim.play("feiqi")


func _update_bomb_jump_rise() -> void:
	# 到达最高点（velocity.y >= 0）→ 切 hongzha 并扔炸弹
	# 注意：不重置 velocity.x，让惯性带飞到对称位置
	if velocity.y >= 0.0:
		_state = State.BOMB_JUMP_FALL
		anim.play("hongzha")
		_drop_bombs()


func _update_bomb_jump_fall() -> void:
	if is_on_floor():
		velocity.x = 0.0
		_enter_chase_with_cd()


func _drop_bombs() -> void:
	# 向下扔出三枚散射炸弹
	var spread_angles = [-0.3, 0.0, 0.3]  # 弧度偏移
	for angle_offset in spread_angles:
		var dir = Vector2(sin(angle_offset), 1.0).normalized()
		var dart = preload("res://scenes/enemy/l3/FireDart.tscn").instantiate() as BombDart
		dart.initialize(dir, bomb_speed)
		dart.global_position = global_position + Vector2(angle_offset * 10, -8)
		get_tree().current_scene.add_child(dart)

	AudioManager.play_sound(&"shibingfashe")


# ==================== SwordHitBox 管理 ====================

func _enable_sword() -> void:
	sword_hitbox.set_deferred("monitoring", true)


func _disable_sword() -> void:
	sword_hitbox.set_deferred("monitoring", false)


# ==================== 动画回调 ====================

func _on_frame_changed() -> void:
	# throw 动画第二帧（索引1）扔炸弹
	if anim.animation == "throw" and anim.frame == 1:
		_do_throw_bomb()


func _on_anim_finished() -> void:
	if anim.animation == death_anim:
		queue_free()
		return
	if is_dead:
		return

	# throw 播完 → 进入 chase with cd
	if anim.animation == "throw":
		_enter_chase_with_cd()


# ==================== 面对玩家 ====================

func _face_player() -> void:
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


# ==================== 显现控制（由生成器调用） ====================

## 开始显现：强制待机，不响应任何玩家探测
func start_appearing() -> void:
	_state = State.APPEARING
	modulate = Color(1, 1, 1, 0)


## 结束显现：切回 IDLE，开始正常战斗
func finish_appearing() -> void:
	if _state == State.APPEARING:
		_state = State.IDLE
		anim.play("idle")


# ==================== 状态切换工具 ====================

func _enter_chase() -> void:
	_state = State.CHASE
	velocity = Vector2.ZERO
	anim.play("idle")
	# 下一次 physics_process 中会判断是否 jump


func _enter_chase_with_cd() -> void:
	_attack_cd = attack_cooldown
	_enter_chase()


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
	# 红色精灵用金黄闪光更明显：Color(8.0, 6.0, 1.0, 1.0) = 金调高亮
	_flash_tween.tween_property(anim, "modulate", Color(8.0, 6.0, 1.0, 1.0), 0.1)
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
