extends Area2D
class_name MechBug

# ════════════════════════════════════════════════════════════
#  MechBug —— 机械虫（去数据驱动版）
#  行为：
#    1. 始终 fly 状态，沿着 Mark 节点下 5 个 Marker2D 记录的初始
#       世界坐标点循环飞行，飞行采用第二关 BOSS 的正弦波逻辑
#    2. 玩家进入 220 范围：身体变黑蓄力 0.5 秒 → 朝玩家方向扇形
#       发射多枚尖刺（第二关 BOSS 必杀技同款投射物）→ 进入 2 秒 CD
#    3. 生命 1，死亡播放 disiwang 音效 + death 动画（与普通小怪一致）
#    4. 无生成音效
# ════════════════════════════════════════════════════════════

# ── 调试参数（改这里即可调整行为） ──
## 飞行移动速度（像素/秒，第二关 BOSS 同款）
const MOVE_SPEED: float = 100.0
## 正弦波振幅（像素）
const SINE_AMPLITUDE: float = 30.0
## 正弦波频率（弧度/秒）
const SINE_FREQUENCY: float = 3.0
## 抵达路径点判定距离（像素）
const REACH_THRESHOLD: float = 10.0
## 触发攻击的玩家距离（像素）
const ATTACK_RANGE: float = 220.0
## 发射前身体变黑蓄力时长（秒）
const CHARGE_DURATION: float = 0.8
## 攻击冷却时间（秒）
const ATTACK_COOLDOWN: float = 2.0
## 尖刺飞行速度（像素/秒）
const SPINE_SPEED: float = 350.0
## 蓄力变黑的最终颜色
const CHARGE_DARK_COLOR: Color = Color(0.3, 0.3, 0.3, 1.0)
## 最大血量
const MAX_HP: int = 1
## 死亡音效（与其他小怪一致）
const DEATH_SOUND: StringName = &"disiwang"
## 尖刺发射音效
const SPINE_SOUND: StringName = &"dandan"

# 第二关 BOSS 必杀技尖刺投射物（文件名含特殊字符，用 uid 加载避免路径错乱）
var _spine_scene: PackedScene = load("uid://dbv1vnsigdbem")

var _waypoints: Array[Vector2] = []
var _current_target_idx: int = 0
var _sine_time: float = 0.0

var _charge_timer: float = -1.0   # >=0 表示正在变黑蓄力中
var _cd_timer: float = 0.0        # 攻击冷却倒计时

var _hp: int = 1
var _is_dead: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox


func _ready() -> void:
	_hp = MAX_HP
	anim.play("fly")
	hurtbox.took_damage.connect(_on_took_damage)
	_collect_waypoints()


## 一次性记录 Mark 节点下 5 个 Marker2D 的初始世界坐标作为固定飞行路径点。
## （参考第四关 BOSS：先入树再取 global_position，防止坐标错乱）
func _collect_waypoints() -> void:
	var mark = get_node_or_null("Mark") as Node2D
	if not mark:
		return
	for child in mark.get_children():
		if child is Marker2D:
			_waypoints.append(child.global_position)


func _process(delta: float) -> void:
	if _is_dead:
		return

	_update_flight(delta)
	_update_attack(delta)


# ==================== 飞行（Mark 路径点循环 + 正弦波） ====================

func _update_flight(delta: float) -> void:
	if _waypoints.is_empty():
		return

	var target = _waypoints[_current_target_idx]
	var diff = target - global_position
	if diff.length() < REACH_THRESHOLD:
		# 抵达当前路径点 → 循环切到下一个点，并重新计算方向
		_current_target_idx = (_current_target_idx + 1) % _waypoints.size()
		target = _waypoints[_current_target_idx]
		diff = target - global_position

	# 直线飞向目标 + 垂直于飞行方向的正弦波（第二关 BOSS 同款逻辑）
	_sine_time += delta
	# normalized() 对零向量返回零向量，避免 0/0 产生 NaN 导致节点消失
	var dir = diff.normalized()
	var perp = Vector2(dir.y, -dir.x)
	var sine_vel = cos(_sine_time * SINE_FREQUENCY) * SINE_AMPLITUDE * SINE_FREQUENCY
	global_position += (dir * MOVE_SPEED + perp * sine_vel) * delta

	# 时刻面朝玩家（第二关 BOSS 飞行同款）
	var player = get_tree().get_first_node_in_group("player")
	if player:
		anim.flip_h = player.global_position.x < global_position.x


# ==================== 攻击（变黑蓄力 → 扇形发射 → CD） ====================

func _update_attack(delta: float) -> void:
	if _cd_timer > 0.0:
		_cd_timer -= delta

	if _charge_timer >= 0.0:
		# 蓄力中：身体变黑（0.5 秒内渐变），到点发射
		_charge_timer -= delta
		var t = 1.0 - _charge_timer / CHARGE_DURATION
		anim.modulate = Color.WHITE.lerp(CHARGE_DARK_COLOR, clampf(t, 0.0, 1.0))
		if _charge_timer <= 0.0:
			anim.modulate = Color.WHITE
			_fire_spines()
			_charge_timer = -1.0
		return

	# 冷却中不触发
	if _cd_timer > 0.0:
		return

	# 玩家进入攻击范围 → 开始变黑蓄力
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if global_position.distance_to(player.global_position) <= ATTACK_RANGE:
		_charge_timer = CHARGE_DURATION


## 朝玩家方向发射一枚尖刺（第二关 BOSS 必杀技同款投射物）
func _fire_spines() -> void:
	AudioManager.play_sound(SPINE_SOUND)

	# 尖刺方向：指向玩家
	var dir: Vector2 = Vector2.RIGHT
	var player = get_tree().get_first_node_in_group("player")
	if player:
		dir = (player.global_position - global_position).normalized()

	var spine = _spine_scene.instantiate()
	# 先入树再设置绝对位置（参考第四关 BOSS：未进树时 global_position 不可靠）
	get_tree().current_scene.add_child(spine)
	spine.global_position = global_position
	spine.initialize(dir, SPINE_SPEED)

	# 进入冷却
	_cd_timer = ATTACK_COOLDOWN


# ==================== 受伤 → 死亡（与普通敌人一致） ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_hp -= amount
	if _hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	set_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
