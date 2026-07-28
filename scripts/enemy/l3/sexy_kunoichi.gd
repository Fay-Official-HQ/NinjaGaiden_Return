extends CharacterBody2D
class_name SexyKunoichi

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 1

## 升龙击·垂直起跳力（负值越高跳越高）
@export var kick_up_vertical_force: float = -300.0
## 升龙击·水平速度（像素/秒，正值即可，自动朝玩家方向）
@export var kick_up_horizontal_speed: float = 250.0

## 前冲飞踢·冲刺距离（像素）
@export var kick_forward_distance: float = 100.0
## 前冲飞踢·冲刺速度（像素/秒）
@export var kick_forward_speed: float = 200.0
## 前冲飞踢·跳跃力（负值让飞踢带弧线）
@export var kick_forward_jump_force: float = -250.0

## 跳跃接近·跳跃力
@export var jump_force: float = -300.0
## 跳跃接近·最小跳跃距离（像素）
@export var jump_min_dist: float = 50.0
## 跳跃接近·最大跳跃距离（像素）
@export var jump_max_dist: float = 80.0

## 天降飞镖·切换 throw_down 动画的临界距离（离玩家X像素内）
@export var throw_down_switch_dist: float = 80.0
## 天降飞镖·跳跃力
@export var throw_down_jump_force: float = -450.0
## 飞镖飞行速度（像素/秒）
@export var dart_speed: float = 400.0
## 飞镖散射角度（度）
@export var dart_spread_angle: float = 25.0

## 攻击间隔（秒）
@export var attack_cooldown: float = 0.3
## 跳跃接近后冷却（秒）
@export var jump_cooldown: float = 0.0
## 攻击前蓄力时长（秒）
@export var charge_duration: float = 0.2
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
@onready var slash_hitbox: Area2D = $SlashHitBox
@onready var slash_collision: CollisionShape2D = $SlashHitBox/CollisionShape2D

# ==================== 状态枚举 ====================

enum State { IDLE, JUMP, CHARGE, KICK_UP, KICK_FORWARD, THROW_DOWN_FLY, THROW_DOWN_ATTACK }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1

var _state: int = State.IDLE
var _attack_cd: float = 0.0
var _jump_cd: float = 0.0

# CHARGE
var _charge_timer: float = 0.0
var _charge_target: int = -1
var _charge_dist: float = 0.0  # 蓄力时记录玩家距离，用于 KICK_UP

# JUMP 接近
var _jump_target_x: float = 0.0
var _jump_wall_count: int = 0  # 翻墙跳跃计数（类似 hopper 壁跳机制，上限5次）

# KICK_FORWARD
var _kick_forward_start_x: float = 0.0
var _kick_forward_dir: float = 1.0

# THROW_DOWN
var _throw_down_player_x: float = 0.0
var _has_thrown_darts: bool = false

var _flash_tween: Tween


func _ready() -> void:
	current_hp = max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	# SlashHitBox 默认关闭，kick_up/kick_forward 时临时开启（已设置为 EnemyHitBox，damage=2）
	slash_hitbox.set_deferred("monitoring", false)

	# 信号连接
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_frame_changed)
	hurtbox.took_damage.connect(_on_took_damage)

	# throw_down 非循环
	anim.sprite_frames.set_animation_loop("throw_down", false)

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_update_player_detection()
	_face_player()

	match _state:
		State.IDLE:
			_update_idle(delta)
		State.JUMP:
			_update_jump(delta)
		State.CHARGE:
			_update_charge(delta)
		State.KICK_UP:
			_update_kick_up(delta)
		State.KICK_FORWARD:
			_update_kick_forward(delta)
		State.THROW_DOWN_FLY:
			_update_throw_down_fly(delta)
		State.THROW_DOWN_ATTACK:
			_update_throw_down_attack(delta)

	move_and_slide()

	# 通用落地检测
	if is_on_floor():
		if _state == State.JUMP:
			_jump_wall_count = 0
			_jump_cd = jump_cooldown
			_enter_idle()
		elif _state == State.KICK_UP:
			_attack_cd = attack_cooldown
			_exit_slash_hitbox()
			_enter_idle()
		elif _state == State.THROW_DOWN_FLY or _state == State.THROW_DOWN_ATTACK:
			_attack_cd = attack_cooldown
			_exit_slash_hitbox()
			_enter_idle()


# ==================== 玩家探测 / 攻击选择 ====================

func _update_player_detection() -> void:
	if _state != State.IDLE:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist = abs(global_position.x - player.global_position.x)

	if not is_on_floor():
		return

	# 新距离规则：
	#   0~100     → CHARGE → 随机 KICK_UP / KICK_FORWARD
	#   100~200   → CHARGE → THROW_DOWN
	#   >200      → JUMP 接近（无蓄力）
	if dist > 200.0:
		if _jump_cd <= 0.0:
			_start_jump_toward_player(player, dist)
	else:
		if _attack_cd <= 0.0:
			_pick_attack_by_distance(player)


func _pick_attack_by_distance(player: Node2D) -> void:
	if is_dead:
		return

	var dist = abs(global_position.x - player.global_position.x)

	if dist <= 100.0:
		# 0~100 随机升龙击或飞踢
		if randi() % 2 == 0:
			_start_charge(State.KICK_UP, dist)
		else:
			_start_charge(State.KICK_FORWARD)
	else:
		# 100~200 空降飞镖（无蓄力，直接跳）
		_start_throw_down(player)


# ==================== IDLE ====================

func _update_idle(delta: float) -> void:
	# 在空中时显示跳跃/坠落动画，落地后自动切回 idle
	if not is_on_floor():
		if anim.animation != "jump":
			anim.play("jump")
	else:
		if anim.animation != "idle":
			anim.play("idle")
	velocity.x = 0.0
	_attack_cd -= delta
	_jump_cd -= delta


# ==================== JUMP（跳跃接近玩家30~50px） ====================

func _start_jump_toward_player(player: Node2D, _dist: float) -> void:
	_state = State.JUMP

	var dx = player.global_position.x - global_position.x
	var dir = 1.0 if dx > 0 else -1.0
	var jump_dist = randf_range(jump_min_dist, jump_max_dist)
	_jump_target_x = global_position.x + dir * jump_dist

	var travel_x = _jump_target_x - global_position.x
	var jump_time = 2.0 * abs(jump_force) / gravity
	velocity.x = travel_x / jump_time if jump_time > 0 else 0.0
	velocity.y = jump_force

	anim.play("jump")


func _update_jump(_delta: float) -> void:
	# 空中保持朝向玩家的水平速度（类似 hopper 持续追击）
	if not is_on_floor():
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dir = 1.0 if player.global_position.x > global_position.x else -1.0
			velocity.x = move_toward(velocity.x, dir * 150.0, 50.0)

	# 撞墙翻越：下落或滞空碰到墙壁且未到上限，则二次跳跃（类似 hopper）
	if is_on_wall() and velocity.y >= 0 and not is_on_floor() and _jump_wall_count < 5:
		_jump_wall_count += 1
		velocity.y = jump_force
		# 水平推向玩家方向，防止被墙壁抵消
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dir = 1.0 if player.global_position.x > global_position.x else -1.0
			velocity.x = dir * 150.0


# ==================== CHARGE（攻击前蓄力0.5s） ====================

func _start_charge(target: int, dist: float = 0.0) -> void:
	_state = State.CHARGE
	_charge_timer = charge_duration
	_charge_target = target
	_charge_dist = dist
	velocity.x = 0.0
	anim.play("idle")


func _update_charge(delta: float) -> void:
	velocity.x = 0.0
	if anim.animation != "idle":
		anim.play("idle")
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		match _charge_target:
			State.KICK_UP:
				_start_kick_up(_charge_dist)
			State.KICK_FORWARD:
				_start_kick_forward()
		_charge_target = -1


# ==================== KICK_UP（升龙击：斜上跳跃 + 攻击框） ====================

func _start_kick_up(_forward_dist: float = 30.0) -> void:
	_state = State.KICK_UP

	# 反向平抛：垂直起跳 + 水平前推，形成抛物线弧线
	var dir = 1.0 if facing_right else -1.0
	velocity.x = dir * kick_up_horizontal_speed
	velocity.y = kick_up_vertical_force

	anim.play("kick_up")
	_enable_slash_hitbox()
	modulate = Color.WHITE


func _update_kick_up(_delta: float) -> void:
	# 落地或撞墙 → 结束
	if is_on_floor() or is_on_wall():
		velocity.x = 0.0
		_attack_cd = attack_cooldown
		_exit_slash_hitbox()
		_enter_idle()


# ==================== KICK_FORWARD（前冲飞踢100px + 攻击框） ====================

func _start_kick_forward() -> void:
	_state = State.KICK_FORWARD
	_kick_forward_start_x = global_position.x
	_kick_forward_dir = 1.0 if facing_right else -1.0

	# 抛物线飞踢：向前 + 微跳，形成弧线
	velocity.x = _kick_forward_dir * kick_forward_speed
	velocity.y = kick_forward_jump_force

	anim.play("kick_forward")
	_enable_slash_hitbox()
	modulate = Color.WHITE


func _update_kick_forward(_delta: float) -> void:
	var traveled = abs(global_position.x - _kick_forward_start_x)
	if traveled >= kick_forward_distance or is_on_wall() or is_on_floor():
		velocity.x = 0.0
		_attack_cd = attack_cooldown
		_exit_slash_hitbox()
		_enter_idle()


# ==================== THROW_DOWN（天降飞镖：飞跃 → 空投3枚散射飞镖） ====================

func _start_throw_down(player: Node2D) -> void:
	_state = State.THROW_DOWN_FLY
	_throw_down_player_x = player.global_position.x
	_has_thrown_darts = false

	# 对称位置：玩家位置为锚点，跳跃到另一侧
	var dx = player.global_position.x - global_position.x
	var target_x = player.global_position.x + dx

	var travel_x = target_x - global_position.x
	var jump_time = 2.0 * abs(throw_down_jump_force) / gravity
	velocity.x = travel_x / jump_time if jump_time > 0 else 0.0
	velocity.y = throw_down_jump_force

	anim.play("fly")


func _update_throw_down_fly(_delta: float) -> void:
	# 离玩家X距离 <= switch_dist → 切换到 throw_down 动画
	var dist_to_player_x = abs(global_position.x - _throw_down_player_x)
	if dist_to_player_x <= throw_down_switch_dist:
		_state = State.THROW_DOWN_ATTACK
		_has_thrown_darts = false
		anim.play("throw_down")


func _update_throw_down_attack(_delta: float) -> void:
	pass  # 由 frame_changed 和 animation_finished 驱动


# ==================== SlashHitBox 管理 ====================

func _enable_slash_hitbox() -> void:
	slash_hitbox.set_deferred("monitoring", true)


func _exit_slash_hitbox() -> void:
	slash_hitbox.set_deferred("monitoring", false)


# ==================== 动画回调 ====================

func _on_frame_changed() -> void:
	# throw_down 第二帧（索引1）射出3枚散射飞镖
	if anim.animation == "throw_down" and anim.frame == 1 and not _has_thrown_darts:
		_spawn_spread_darts()
		_has_thrown_darts = true


func _on_anim_finished() -> void:
	# 死亡动画优先
	if anim.animation == death_anim:
		queue_free()
		return
	if is_dead:
		return

	# throw_down 动画播完 → 保持最后一帧，等落地检测处理
	# （已在 _physics_process 落地检测中处理 CD 和 idle 过渡）


# ==================== 3枚散射飞镖 ====================

func _spawn_spread_darts() -> void:
	AudioManager.play_sound(&"rengbiao")

	var angles = [-dart_spread_angle, 0.0, dart_spread_angle]
	for angle_deg in angles:
		var angle_rad = deg_to_rad(angle_deg)
		# 朝下扇形散射
		var dir = Vector2(sin(angle_rad), cos(angle_rad)).normalized()

		var dart = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn").instantiate()
		dart.global_position = global_position + Vector2(0, 4)
		get_tree().current_scene.add_child(dart)
		dart.initialize(dir, dart_speed)


# ==================== 面对玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != facing_right:
		facing_right = should_face_right
		anim.flip_h = not should_face_right
		# SlashHitBox 同步翻转：碰撞体位置镜像
		slash_collision.position.x = -slash_collision.position.x


# ==================== 通用 ====================

func _enter_idle() -> void:
	_state = State.IDLE
	velocity.x = 0.0
	anim.play("idle")
	modulate = Color.WHITE  # 安全恢复颜色


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
	_exit_slash_hitbox()
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
