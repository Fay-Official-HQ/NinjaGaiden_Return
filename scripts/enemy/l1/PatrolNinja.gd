
# 移动扔镖忍者：周期性左右巡逻，玩家进入检测范围后停下并持续扔镖
#
# ── 行为状态切换 ──
#   PATROL（默认）→ 左右巡逻，检测边缘掉头
#   THROW（玩家进入 DetectRange）→ 面朝玩家，每3秒扔一次飞镖
#   玩家离开 DetectRange → 回到 PATROL
#
#
# ── 注意事项 ──
#   1. DetectRange 的 collision_mask 必须包含玩家所在的碰撞层
#   2. PatrolNinjaData.tres 需在 Inspector 中绑定到 data 字段
#   3. dart_data 子字段也需绑定 DartData.tres
#   4.DetectRange 它的碰撞设置默认（1，1）即可，这种检测区域和蝙蝠、老鹰生成器一样的
# ============================================================

extends BaseEnemy
class_name PatrolNinja


# ── 内部状态枚举 ──
enum NinjaState { PATROL, THROW }


# ── 节点引用（场景必须包含同名节点） ──
@onready var detect_range: Area2D = $DetectRange
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight


# ── 运行时状态 ──
var _ninja_state: int = NinjaState.PATROL
var _start_position: Vector2
var _throw_cooldown: float = 0.0


func _ready() -> void:
	super()                     # 连接 HurtBox 信号
	_start_position = global_position

	# 检测玩家进入/离开范围
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)

	# 动画播放完毕信号（一次性连接，永久有效）
	anim.animation_finished.connect(_on_throw_finished)

	# 初始化动画
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	match _ninja_state:
		NinjaState.PATROL:
			_update_patrol(delta)
		NinjaState.THROW:
			_update_throw(delta)

	# 必须调用，BaseEnemy 不自带
	move_and_slide()


# ==================== 巡逻状态 ====================

func _update_patrol(_delta: float) -> void:
	anim.play("walk")
	_check_turn()
	velocity.x = data.move_speed * (1.0 if facing_right else -1.0)


# 转弯检测：走到平台边缘 → 掉头
func _check_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)
		return

	# 巡逻半径范围限制
	var distance = global_position.x - _start_position.x
	if distance > 100.0:
		_set_facing(false)
	elif distance < -100.0:
		_set_facing(true)


# ==================== 投掷状态 ====================

func _update_throw(delta: float) -> void:
	# 面朝玩家，原地不动
	_face_player()
	velocity.x = 0.0

	# 不打断扔镖动画，只在不投掷时播放闲置站立
	if anim.animation != "throw":
		anim.play("idle")

	# 扔镖冷却计时
	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0:
		var ninja_data = data as PatrolNinjaData
		# fallback: 即使 data 丢失也要重置冷却，否则永远不攻击
		_throw_cooldown = ninja_data.attack_cooldown if ninja_data else 2.0
		if ninja_data:
			_throw_dart()


# 扔出一枚飞镖
func _throw_dart() -> void:
	var ninja_data = data as PatrolNinjaData
	if not ninja_data or not ninja_data.dart_data:
		return

	var dart = preload("res://scenes/enemy/l1/dart.tscn").instantiate()
	var dir = Vector2.RIGHT if facing_right else Vector2.LEFT

	# 飞镖出生位置：忍者胸前
	dart.global_position = global_position + Vector2(14 if facing_right else -14, -8)
	get_tree().current_scene.add_child(dart)

	# 必须在 add_child 之后调用 initialize，
	# 否则 @onready 变量还未初始化，Sprite2D 为 null
	dart.initialize(dir, ninja_data.dart_data)

	# 播放扔镖动画（单次），播完后 _on_throw_finished 自动接管
	anim.play("throw")


func _on_throw_finished() -> void:
	if is_dead:
		return
	# 视当前状态播对应动画
	if _ninja_state == NinjaState.THROW:
		anim.play("idle")
	else:
		anim.play("walk")


# ==================== 朝向玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


# ==================== 玩家检测（DetectRange 信号） ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_ninja_state = NinjaState.THROW
	_throw_cooldown = 0.0  # 进入范围立刻先发第一镖


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_ninja_state = NinjaState.PATROL


# ==================== 重力 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
