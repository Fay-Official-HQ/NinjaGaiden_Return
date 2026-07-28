extends CharacterBody2D
class_name Kunoichi

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 1
## 巡逻速度（像素/秒）
@export var patrol_speed: float = 30.0
## 巡逻范围（像素，0=无限制）
@export var patrol_range: float = 80.0
## 前冲刺·接近阶段速度（像素/秒）
@export var approach_speed: float = 150.0
## 冲刺速度（像素/秒）
@export var dash_speed: float = 350.0
## 冲刺距离（像素）
@export var dash_distance: float = 100.0
## 跳跃力（垂直初速度）
@export var jump_force: float = 350.0
## 飞镖飞行速度（像素/秒）
@export var dart_speed: float = 400.0
## 攻击间隔（秒）
@export var attack_cooldown: float = 0.5
## 玩家探测距离（像素）
@export var detect_range: float = 175.0
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

enum State { IDLE, PATROL, JUMP, THROW, DASH_APPROACH, DASH_CHARGE, DASH_ATTACK }
enum AttackType { JUMP, THROW, DASH }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1
var _start_position: Vector2

var _state: int = State.PATROL
var _attack_cd: float = 0.0
var _player_in_range: bool = false

# 跳跃
var _jump_target_x: float = 0.0

# 扔飞镖
var _is_throwing: bool = false

# 冲刺
var _dash_start_x: float = 0.0
var _dash_dir: float = 1.0
var _dash_charge_timer: float = 0.0

var _flash_tween: Tween


func _ready() -> void:
	current_hp = max_hp
	_start_position = global_position

	# 设置 HitBox 接触伤害
	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	# 信号连接
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_throw_frame_changed)
	hurtbox.took_damage.connect(_on_took_damage)

	# throw 动画必须非循环
	anim.sprite_frames.set_animation_loop("throw", false)
	anim.sprite_frames.set_animation_loop("dash", false)

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
		State.PATROL:
			_update_patrol(delta)
		State.JUMP:
			_update_jump(delta)
		State.THROW:
			_update_throw(delta)
		State.DASH_APPROACH:
			_update_dash_approach(delta)
		State.DASH_CHARGE:
			_update_dash_charge(delta)
		State.DASH_ATTACK:
			_update_dash_attack(delta)

	move_and_slide()

	# 跳跃落地检测
	if _state == State.JUMP and is_on_floor():
		_enter_attack_idle()


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
	_pick_random_attack()


func _on_player_exited_range() -> void:
	_state = State.PATROL
	_attack_cd = 0.0
	_is_throwing = false


# ==================== 随机选择攻击 ====================

func _pick_random_attack() -> void:
	if is_dead:
		return
	var attacks = [AttackType.JUMP, AttackType.THROW, AttackType.DASH]
	var chosen = attacks[randi() % attacks.size()]
	match chosen:
		AttackType.JUMP:
			_start_jump()
		AttackType.THROW:
			_start_throw()
		AttackType.DASH:
			_start_dash_approach()


# ==================== 状态更新 ====================

func _update_idle(delta: float) -> void:
	if anim.animation != "idle":
		anim.play("idle")
	_attack_cd -= delta
	if _attack_cd <= 0.0 and _player_in_range:
		_pick_random_attack()


func _update_patrol(_delta: float) -> void:
	# 巡逻：遇到断崖、墙壁或超出巡逻范围时转弯
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	var at_edge = not edge_ray.is_colliding()
	var at_wall = is_on_wall()

	# 巡逻范围限制（非零时生效）
	var out_of_range = false
	if patrol_range > 0.0:
		out_of_range = abs(global_position.x - _start_position.x) >= patrol_range

	if at_edge or at_wall or out_of_range:
		_set_facing(not facing_right)

	velocity.x = patrol_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")


func _update_jump(_delta: float) -> void:
	# 跳跃到目标位置，水平速度已由 _start_jump 算好
	# 这里只播放动画，垂直速度由重力处理
	pass


func _update_throw(_delta: float) -> void:
	if anim.animation != "throw" and not _is_throwing:
		_is_throwing = true
		anim.play("throw")


func _update_dash_approach(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_state = State.PATROL
		return

	# 靠近玩家直到 100 像素内，然后蓄力
	var dist = abs(global_position.x - player.global_position.x)
	if dist <= dash_distance:
		_start_dash_charge()
		return

	velocity.x = approach_speed * (1.0 if facing_right else -1.0)
	if anim.animation != "walk":
		anim.play("walk")


func _update_dash_attack(_delta: float) -> void:
	# 冲刺移动
	velocity.x = _dash_dir * dash_speed

	# 冲刺距离到了就结束
	var traveled = abs(global_position.x - _dash_start_x)
	if traveled >= dash_distance or is_on_wall():
		velocity.x = 0.0
		_enter_attack_idle()


func _update_dash_charge(delta: float) -> void:
	# 蓄力，播放待机动画
	velocity.x = 0.0
	if anim.animation != "idle":
		anim.play("idle")
	_dash_charge_timer -= delta
	if _dash_charge_timer <= 0.0:
		_start_dash_attack()


# ==================== 攻击开始 ====================

func _start_jump() -> void:
	_state = State.JUMP
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		_state = State.PATROL
		return

	_jump_target_x = player.global_position.x

	# 计算水平速度：用跳跃总时间推算
	var dx = _jump_target_x - global_position.x
	var jump_time = 2.0 * jump_force / gravity
	velocity.x = dx / jump_time
	velocity.y = -jump_force

	anim.play("jump")
	AudioManager.play_sound(&"tiaoyue")


func _start_throw() -> void:
	_state = State.THROW
	_is_throwing = false
	velocity.x = 0.0


func _start_dash_approach() -> void:
	_state = State.DASH_APPROACH
	velocity.x = 0.0


func _start_dash_charge() -> void:
	_state = State.DASH_CHARGE
	_dash_charge_timer = 0.2
	velocity.x = 0.0
	anim.play("idle")


func _start_dash_attack() -> void:
	_state = State.DASH_ATTACK
	_dash_start_x = global_position.x
	_dash_dir = 1.0 if facing_right else -1.0
	anim.play("dash")
	AudioManager.play_sound(&"luoren")


# ==================== 攻击结束 → 待机 ====================

func _enter_attack_idle() -> void:
	_state = State.IDLE
	_attack_cd = attack_cooldown
	_is_throwing = false
	velocity.x = 0.0
	anim.play("idle")


# ==================== 动画回调 ====================

func _on_throw_frame_changed() -> void:
	# 第二帧（索引 1）射出飞镖
	if anim.animation == "throw" and anim.frame == 1:
		_spawn_dart()


func _on_anim_finished() -> void:
	# 死亡动画优先
	if anim.animation == death_anim:
		queue_free()
		return

	if is_dead:
		return

	# throw 动画播完 → 进待机冷却
	if anim.animation == "throw":
		_enter_attack_idle()


# ==================== 扔飞镖 ====================

func _spawn_dart() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# 计算朝向玩家的方向向量
	var dir = (player.global_position - global_position).normalized()

	var dart = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn").instantiate()
	dart.global_position = global_position + dir * 14 + Vector2(0, -4)
	get_tree().current_scene.add_child(dart)
	dart.initialize(dir, dart_speed)

	# 播放和飞行忍者一样的飞镖音效
	AudioManager.play_sound(&"rengbiao")


# ==================== 面对玩家 ====================

func _face_player() -> void:
	if _state == State.PATROL:
		return  # 巡逻时不管玩家方向
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != facing_right:
		_set_facing(should_face_right)


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right


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
