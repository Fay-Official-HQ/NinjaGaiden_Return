# BombNinja —— 下蹲炸弹忍者
# ============================================================
#  行为模式：
#    1. 原地不动，面朝玩家
#    2. DetectRange 检测到玩家 → 持续投掷 BombDart
#    3. 投掷间隔可调
# ============================================================
extends CharacterBody2D
class_name BombNinja

enum NinjaState { IDLE, THROW }

# ── 预加载（编译时加载一次，避免运行时反复 IO） ──
const BOMB_DART_SCENE = preload("res://scenes/enemy/l3/BombDart.tscn")

# ── 节点引用（场景结构固定，直接 $ 访问） ──
# 【调试】AnimatedSprite2D 是必选子节点，不要改名
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
# 【调试】HurtBox 被玩家攻击框检测到时触发受伤
@onready var hurtbox: Area2D = $HurtBox
# 【调试】HitBox 是身体碰撞伤害框，接触玩家造成伤害
@onready var hitbox: Area2D = $HitBox
# 【调试】DetectRange 是 Area2D，碰撞形状覆盖全屏或指定区域
@onready var detect_range: Area2D = $DetectRange

# ── @export 导出参数（Inspector 中可直接调试） ──

## 【调试】最大生命值
@export var max_hp: int = 1
## 【调试】重力加速度（像素/秒²）
@export var gravity: float = 980.0
## 【调试】身体接触伤害值
@export var contact_damage: int = 1
## 【调试】投掷冷却时间（秒），检测到玩家后每隔 attack_cooldown 秒扔一次炸弹
@export var attack_cooldown: float = 2.0
## 【调试】炸弹飞镖飞行速度（像素/秒）
@export var dart_speed: float = 250.0
## 【调试】死亡动画名称（在 SpriteFrames 中定义的动画名）
@export var death_anim: String = "death"
## 【调试】死亡音效 ID（在 AudioManager 中注册的键名）
@export var death_sound: StringName = &"disiwang"
## 【调试】初始面朝方向（true=面朝右，false=面朝左）
@export var initial_facing_right: bool = true

# ── 运行时状态 ──

var is_dead: bool = false
var facing_right: bool = true
var current_hp: int = 1

var _state: int = NinjaState.IDLE
var _throw_cooldown: float = 0.0


func _ready() -> void:
	# 初始化血量
	current_hp = max_hp

	# 初始朝向
	facing_right = initial_facing_right
	anim.flip_h = not facing_right

	# 设置 HitBox 接触伤害
	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	# 信号连接
	hurtbox.took_damage.connect(_on_took_damage)
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_anim_finished)

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_face_player()
	velocity.x = 0.0

	match _state:
		NinjaState.IDLE:
			_update_idle()
		NinjaState.THROW:
			_update_throw(delta)

	move_and_slide()


# ==================== 状态更新 ====================

func _update_idle() -> void:
	# 【调试】待机时始终播放 idle 动画
	if anim.animation != "idle":
		anim.play("idle")


func _update_throw(delta: float) -> void:
	# 【调试】冷却期间保持 idle 动画，投掷时才切 throw
	if anim.animation != "throw":
		anim.play("idle")

	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0:
		_throw_dart()
		_throw_cooldown = attack_cooldown


# ==================== 投掷炸弹 ====================

func _throw_dart() -> void:
	# 【调试】找不到玩家则放弃投掷（通常不会发生）
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# 【调试】dir 是从忍者指向玩家的单位向量，炸弹沿此方向飞行
	var dir = (player.global_position - global_position).normalized()

	# 【调试】实例化 BombDart 并初始化
	#   - initialize(dir, dart_speed)：dir 是 Vector2 方向，dart_speed 是标量速度
	#   - 炸弹出生偏移：dir * 14（水平偏移） + Vector2(0, 7)（垂直向下偏移）
	#   - 调大 14 → 炸弹更远离身体；调小 → 更贴近；负值 → 从身后飞出
	#   - 调 Vector2(0, 7) 的 7 → 正数向下偏，负数向上偏
	var dart = BOMB_DART_SCENE.instantiate() as BombDart
	dart.initialize(dir, dart_speed)
	dart.global_position = global_position + dir * 14 + Vector2(0, 7)
	get_tree().current_scene.add_child(dart)

	# 【调试】throw 动画只有 1 帧（2秒时长），播完后由 _on_anim_finished 切回 idle
	anim.play("throw")


# ==================== 面对玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right


# ==================== 玩家进出探测 ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# 【调试】玩家进入 DetectRange 后立即开始投掷，冷却计时归零
	_state = NinjaState.THROW
	_throw_cooldown = 0.0


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	# 【调试】玩家离开 DetectRange 后切回待机
	_state = NinjaState.IDLE


# ==================== 动画回调 ====================

func _on_anim_finished() -> void:
	# 死亡动画播完 → 销毁
	if anim.animation == death_anim:
		queue_free()
		return
	if is_dead:
		return

	# throw 动画播完 → 切回 idle
	if anim.animation == "throw":
		anim.play("idle")


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

	# 【调试】如果 death_anim 在 SpriteFrames 中不存在，不会崩溃，只是不播动画
	if anim.sprite_frames and anim.sprite_frames.has_animation(death_anim):
		anim.play(death_anim)
	else:
		# 【调试】没有死亡动画则直接销毁
		queue_free()


# ==================== 物理 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
