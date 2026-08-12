extends BaseEnemy
class_name FemalePistol


## ============================================================
##  1. 不追击，原地站立，每帧面向玩家
##  2. 玩家进入探测距离（默认 300，可调）后开始射击
##  3. 每隔 attack_cooldown 秒朝面朝方向（水平左/右）发射一枚狙击子弹
## ============================================================

# ── 可调数据（Inspector 可调） ──
## 探测距离（像素），玩家进入该距离后开始射击
@export var detect_distance: float = 200.0
## 每次射击的间隔（秒）
@export var attack_cooldown: float = 1.0
## 狙击子弹飞行速度（像素/秒）
@export var bullet_speed: float = 600.0
## 子弹出生点相对本体的水平偏移（像素，沿面朝方向偏移）
@export var spawn_offset_h: float = 10.0
## 子弹出生点相对本体的垂直偏移（像素，正数=向下）
@export var spawn_offset_v: float = 5.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 射击音效
@export var fire_sound: StringName = &"shouqiang"
## 死亡动画名
@export var death_anim: String = "death"

## 狙击子弹场景（与 AK 士兵同款，水平飞行）
const SNIPER_BULLET_SCENE: PackedScene = preload("res://scenes/enemy/l5/soldier_bullet2.tscn")

var _shoot_timer: float = 0.0
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
		_shoot_timer -= delta
		if _shoot_timer <= 0.0:
			_shoot_timer = attack_cooldown
			_fire_bullet()
	else:
		# throw 播放完毕后才能回到 idle
		if not _is_throwing:
			anim.play("idle")

	move_and_slide()


## 朝面朝方向（水平左/右）发射一枚狙击子弹
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
