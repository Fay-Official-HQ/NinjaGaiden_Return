extends BaseEnemy
class_name MachineGunner


## ============================================================
##  1. 不追击，原地站立，每帧面向玩家
##  2. 玩家进入探测距离（默认 250，可调）后开始射击
##  3. 像 AK 士兵一样一轮点射（burst_count 发，可调 1~5），
##     一轮之内按 burst_interval（每一发的间隔）逐发连续射出水平子弹
##  4. 一轮打完 → attack_cooldown 冷却（轮与轮之间的停顿）→ 开始下一轮
##     ★ 注意：burst_interval（每发间隔）≠ attack_cooldown（轮间CD）
## ============================================================

# ── 可调数据（Inspector 可调） ──
## 探测距离（像素），玩家进入该距离后开始射击
@export var detect_distance: float = 250.0
## 【连射间隔】每一轮点射内，每一发子弹之间的间隔（秒）。
##   例：burst_count=3 时，第 1 发在 t=0，第 2 发在 t=burst_interval，
##       第 3 发在 t=2×burst_interval。
##   ★ 这是每一发之间的间隔，不是轮与轮之间的 CD（看 attack_cooldown）
@export var burst_interval: float = 0.1
## 一轮点射的子弹数量（1~5，像步枪点射一样逐发连续射出）
@export_range(1, 5, 1) var burst_count: int = 3
## 【轮间冷却 CD】一轮点射全部打完，到下一轮点射开始之间的停顿（秒）。
##   ★ 与 burst_interval（每发间隔）不同，调这个只改轮与轮之间的节奏
@export var attack_cooldown: float = 0.5
## 子弹飞行速度（像素/秒）
@export var bullet_speed: float = 600.0
## 子弹出生点相对本体的水平偏移（像素，沿面朝方向偏移）
@export var spawn_offset_h: float = 20.0
## 子弹出生点相对本体的垂直偏移（像素，正数=向下）
@export var spawn_offset_v: float = 13.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 射击音效
@export var fire_sound: StringName = &"jiqiang"
## 死亡动画名
@export var death_anim: String = "death"

## 子弹场景（与 AK 士兵同款，水平飞行）
const SNIPER_BULLET_SCENE: PackedScene = preload("res://scenes/enemy/l5/soldier_bullet2.tscn")

## 下一轮点射的启动倒计时（秒，即轮间 CD attack_cooldown）
var _shoot_timer: float = 0.0
## 是否正在一轮点射中
var _is_bursting: bool = false
## 本轮已发射的子弹数量
var _burst_fired: int = 0
## 下一发子弹的倒计时（秒，每轮内按 burst_interval 计）
var _burst_timer: float = 0.0
## 是否正在播放 throw 开火动画（播放完毕后才能回到 idle）
var _is_throwing: bool = false


func _ready() -> void:
	super()
	current_hp = max_hp
	anim.animation_finished.connect(_on_throw_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 站立不动，时刻面对玩家
	_face_player()
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += 980.0 * delta

	# 玩家是否在探测距离内
	var player = get_tree().get_first_node_in_group("player")
	var player_in_range: bool = player != null and global_position.distance_to(player.global_position) <= detect_distance

	if player_in_range:
		_update_firing(delta)
	else:
		# 玩家离开范围：中断本轮点射
		_is_bursting = false
		_burst_fired = 0
		# throw 播放完毕后才能回到 idle
		if not _is_throwing:
			anim.play("idle")

	move_and_slide()


## 射击状态机：一轮点射（每发间隔 burst_interval）→ 轮间 CD（attack_cooldown）→ 下一轮
func _update_firing(delta: float) -> void:
	if _is_bursting:
		# 一轮点射中：等满 burst_interval（每一发的间隔）后打出下一发
		_burst_timer -= delta
		if _burst_timer <= 0.0:
			if _burst_fired < burst_count:
				_burst_timer = burst_interval
				_burst_fired += 1
				_fire_bullet()
			else:
				# 本轮点射结束 → 进入轮间 CD
				_is_bursting = false
				_shoot_timer = attack_cooldown
	else:
		# 轮间 CD 中，等 throw 动画播完再开始下一轮
		if _is_throwing:
			return
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			# 开始一轮点射：立即打出第一发（t=0），后续每发间隔 burst_interval
			_is_bursting = true
			_burst_fired = 1
			_burst_timer = burst_interval
			_fire_bullet()


## 朝面朝方向（水平左/右）发射 1 发子弹
func _fire_bullet() -> void:
	var dir = 1.0 if facing_right else -1.0
	var origin = global_position + Vector2(spawn_offset_h * dir, spawn_offset_v)

	var bullet = SNIPER_BULLET_SCENE.instantiate()
	bullet.global_position = origin
	get_tree().current_scene.add_child(bullet)
	bullet.initialize(dir, bullet_speed)

	AudioManager.play_sound(fire_sound)
	_is_throwing = true
	anim.play("throw")


## throw 开火动画播放完毕，回到 idle
func _on_throw_finished() -> void:
	if is_dead:
		return
	_is_throwing = false
	anim.play("idle")


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


# 无数据驱动：死亡流程使用导出的音效/动画参数，不复用 data 资源
func _die() -> void:
	is_dead = true
	AudioManager.play_sound(death_sound)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play(death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
