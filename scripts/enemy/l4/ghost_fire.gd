# 鬼火（第四关敌人）
#
# 行为：
#   1. 由 GhostFireSpawner 生成（一次可生成多个）
#   2. 生成后原位待机 idle_time 秒（默认2秒），然后以 chase_speed 慢慢飞向并追踪玩家，
#      除非被杀死否则永不停止
#   3. 玩家碰撞到鬼火受到 1 点伤害（由 EnemyHitBox 完成，damage=1）
#   4. 生命 1 点，受伤/死亡伤害逻辑与音效和普通敌人一致（disiwang + death 动画）
#
# 碰撞层（与普通敌人/monster_laser 一致）：
#   - 本体 Area2D：collision_layer = 2
#   - HurtBox：collision_layer = 2, collision_mask = 16（被玩家攻击检测）
#   - EnemyHitBox：collision_layer = 32（检测玩家 HurtBox，造成 1 点伤害）
extends Area2D
class_name GhostFire

enum GhostState { IDLE, CHASE }

## 生成后原地待机时间（秒）
@export var idle_time: float = 2.0
## 追踪玩家的飞行速度（像素/秒），慢慢接近
@export var chase_speed: float = 60.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 死亡动画名
@export var death_anim: String = "death"

var _state: int = GhostState.IDLE
var _idle_timer: float = 0.0
var _hp: int = 1
var _is_dead: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var enemy_hitbox: Area2D = $EnemyHitBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	_hp = max_hp
	_idle_timer = idle_time
	hurt_box.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.play("idle")


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _state:
		GhostState.IDLE:
			_update_idle(delta)
		GhostState.CHASE:
			_update_chase(delta)


# ==================== 待机（原位不动） ====================

func _update_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_state = GhostState.CHASE
		anim.play("fly")


# ==================== 追踪（慢慢接近玩家，永不停止） ====================

func _update_chase(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	global_position += dir * chase_speed * delta
	anim.flip_h = dir.x < 0


# ==================== 受伤 → 死亡（与普通敌人一致） ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_hp -= amount
	if _hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(death_sound)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	enemy_hitbox.set_deferred("monitoring", false)
	enemy_hitbox.set_deferred("monitorable", false)
	set_process(false)
	anim.play(death_anim)
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == death_anim:
		queue_free()


# 飞出屏幕销毁，避免鬼火无限堆积
func _on_screen_exited() -> void:
	if not _is_dead:
		queue_free()
