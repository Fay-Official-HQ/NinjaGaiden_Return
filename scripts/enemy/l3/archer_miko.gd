extends CharacterBody2D
class_name ArcherMiko

# ==================== 导出调试参数 ====================

## 最大血量
@export var max_hp: int = 1
## 箭矢飞行速度（像素/秒）
@export var arrow_speed: float = 600.0
## 两次射击间隔（秒）
@export var shoot_cooldown: float = 1.0
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
@onready var detect_range: Area2D = $DetectRange

# ==================== 状态枚举 ====================

enum State { IDLE, THROW }

# ==================== 运行时状态 ====================

var facing_right: bool = true
var is_dead: bool = false
var current_hp: int = 1

var _state: int = State.IDLE
var _throw_cooldown: float = 0.0
var _is_charging: bool = false     # 是否正在播放射箭动画中


func _ready() -> void:
	current_hp = max_hp

	# 设置 HitBox 接触伤害
	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	# 信号连接
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_anim_finished)
	anim.frame_changed.connect(_on_throw_frame_changed)
	hurtbox.took_damage.connect(_on_took_damage)

	# throw 动画必须非循环，否则 animation_finished 不会触发
	anim.sprite_frames.set_animation_loop("throw", false)

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_face_player()
	velocity.x = 0.0

	match _state:
		State.IDLE:
			_update_idle(delta)
		State.THROW:
			_update_throw(delta)

	move_and_slide()


# ==================== 状态更新 ====================

func _update_idle(_delta: float) -> void:
	if anim.animation != "idle":
		anim.play("idle")


func _update_throw(delta: float) -> void:
	# 冷却中，等待
	if _throw_cooldown > 0.0:
		_throw_cooldown -= delta
		if anim.animation != "idle" and not _is_charging:
			anim.play("idle")
		return

	# 不在蓄力射箭中，开始射箭动画
	if not _is_charging:
		_is_charging = true
		anim.play("throw")


# ==================== 动画回调 ====================

func _on_throw_frame_changed() -> void:
	# 第二帧（索引 1）射出箭矢，不等动画播完
	if anim.animation == "throw" and anim.frame == 1:
		_spawn_arrow()


func _on_anim_finished() -> void:
	# 死亡动画优先处理：必须在 is_dead 判断之前，否则永远执行不到
	if anim.animation == death_anim:
		queue_free()
		return

	if is_dead:
		return

	if anim.animation == "throw":
		_throw_cooldown = shoot_cooldown
		_is_charging = false
		anim.play("idle")


# ==================== 射箭 ====================

func _spawn_arrow() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# 计算朝向玩家的水平方向
	var dir = 1.0 if player.global_position.x > global_position.x else -1.0

	var arrow_instance = preload("res://scenes/enemy/l3/arrow.tscn").instantiate()
	arrow_instance.global_position = global_position + Vector2(dir * 16, 0)
	get_tree().current_scene.add_child(arrow_instance)
	arrow_instance.initialize(dir, arrow_speed)

	# 射箭音效（复用玩家跳跃音效）
	AudioManager.play_sound(&"tiaoyue")


# ==================== 面对玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var should_face_right = player.global_position.x > global_position.x
	if should_face_right != facing_right:
		facing_right = should_face_right
		anim.flip_h = not facing_right


# ==================== 检测区域 ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = State.THROW


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = State.IDLE
	_is_charging = false
	_throw_cooldown = 0.0


# ==================== 受伤/死亡 ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()


func _die() -> void:
	is_dead = true

	AudioManager.play_sound(death_sound)

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)

	if anim.sprite_frames and anim.sprite_frames.has_animation(death_anim):
		anim.play(death_anim)
	else:
		queue_free()


# ==================== 物理 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
