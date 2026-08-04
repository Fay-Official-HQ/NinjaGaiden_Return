# 蛇头射手（第四关敌人）：原地不动，面朝玩家，全屏检测，持续发射激光
# 无数据驱动：所有可调参数均为 @export，直接在 Inspector 中调试
extends BaseEnemy
class_name SnakeheadShooter

enum NinjaState { IDLE, THROW }

## 发射冷却时间（秒）：检测到玩家后每隔 attack_cooldown 秒发射一次激光
@export var attack_cooldown: float = 1.5
## 激光飞行速度（像素/秒）
@export var laser_speed: float = 300.0
## 激光出生点相对本体的水平偏移（像素，正数=向玩家方向偏移）
@export var spawn_offset_h: float = 0.0
## 激光出生点相对本体的垂直偏移（像素，正数=向下）
@export var spawn_offset_v: float = -5.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 每次发射激光时的音效
@export var fire_sound: StringName = &"dandan"
## 死亡动画名
@export var death_anim: String = "death"

const LASER_SCENE: PackedScene = preload("res://scenes/enemy/l2/monster_laser.tscn")

@onready var detect_range: Area2D = $DetectRange

var _state: int = NinjaState.IDLE
var _throw_cooldown: float = 0.0


func _ready() -> void:
	super()
	current_hp = max_hp
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_throw_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_face_player()
	velocity.x = 0.0

	match _state:
		NinjaState.IDLE:
			_update_idle(delta)
		NinjaState.THROW:
			_update_throw(delta)

	move_and_slide()


func _update_idle(_delta: float) -> void:
	anim.play("idle")


func _update_throw(delta: float) -> void:
	if anim.animation != "throw":
		anim.play("idle")

	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0:
		_fire_laser()
		_throw_cooldown = attack_cooldown


func _fire_laser() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var laser = LASER_SCENE.instantiate()
	var dir = (player.global_position - global_position).normalized()
	laser.global_position = global_position + dir * spawn_offset_h + Vector2(0, spawn_offset_v)
	get_tree().current_scene.add_child(laser)
	laser.initialize(dir, laser_speed)
	AudioManager.play_sound(fire_sound)

	anim.play("throw")


func _on_throw_finished() -> void:
	if is_dead:
		return
	anim.play("idle")


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = NinjaState.THROW
	_throw_cooldown = 0.0


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = NinjaState.IDLE


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta


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
