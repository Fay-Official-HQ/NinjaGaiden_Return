extends BaseEnemy
class_name RPGSoldier

## ============================================================
##  1. 不追击，原地站立，每帧面向玩家
##  2. 玩家进入探测距离（默认 300，可调）后开始射击
##  3. 每隔 attack_cooldown 秒朝面朝方向（水平左/右）发射一枚狙击子弹
## ============================================================

# ── 可调数据（Inspector 可调） ──
## 探测距离（像素），玩家进入该距离后开始射击
@export var detect_distance: float = 300.0
## 每次射击的间隔（秒）
@export var attack_cooldown: float = 3.5
## 狙击子弹飞行速度（像素/秒）
@export var bullet_speed: float = 400.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 射击音效
@export var fire_sound: StringName = &"jianci"
## 死亡动画名
@export var death_anim: String = "death"

## 狙击子弹场景（与 AK 士兵同款，水平飞行）
const SNIPER_BULLET_SCENE: PackedScene = preload("res://scenes/enemy/l5/RPG.tscn")

## 发射点 Marker2D（场景中按朝右摆放），导弹从这里生成，翻转朝向时 x 镜像
@onready var throw_point: Marker2D = $Marker2D

var _shoot_timer: float = 0.0
## 是否正在播放 throw 开火动画（播放完毕后才能回到 idle）
var _is_throwing: bool = false


func _ready() -> void:
	super()
	current_hp = max_hp
	# 初始不朝右时，发射点也需镜像（场景中 Marker2D 按朝右摆放）
	if not facing_right:
		throw_point.position.x = -throw_point.position.x
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


## 朝面朝方向（水平左/右）发射一枚 RPG 导弹，不瞄准玩家
func _fire_bullet() -> void:
	var dir = Vector2.RIGHT if facing_right else Vector2.LEFT

	var bullet = SNIPER_BULLET_SCENE.instantiate()
	bullet.global_position = throw_point.global_position
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


## 翻转朝向：精灵 flip_h + 镜像发射点（Marker2D 场景中按朝右摆放）
func _set_facing(right: bool) -> void:
	if facing_right == right:
		return
	facing_right = right
	anim.flip_h = not right
	throw_point.position.x = -throw_point.position.x


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
