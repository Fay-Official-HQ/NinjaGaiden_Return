# 蓝色鬼火（BOSS4 聚集火焰）
#
# 由 BOSS4 在 Marker2D~Marker2D4 四个点生成，通过 initialize(target_pos) 传入
# 目标坐标（Marker2D5 位置），生成后慢慢飞向目标坐标聚集，到达后发出
# reached_target 信号通知 BOSS（用于统计本轮聚集的火焰数量）。
#
# 行为：
#   1. 生成后短暂待机 idle_time 秒（默认 2，原地静止），然后以 fly_speed 慢慢飞向目标坐标
#   2. 到达目标坐标（距离 <= reach_threshold）→ 发 reached_target 信号 → 静默消失
#      （不播放死亡动画/音效，BOSS 统计为"已聚集"）
#   3. 玩家碰撞到火焰受到 1 点伤害（由 EnemyHitBox 完成，damage=1）
#   4. 可被玩家攻击摧毁（HurtBox），被攻击打死才播放死亡动画 + 死亡音效，
#      被打掉视为"未聚集"（BOSS 据此决定伤害/是否发射能量波）
#
# 碰撞层（与 ghost_fire 一致）：
#   - 本体 Area2D：collision_layer = 2
#   - HurtBox：collision_layer = 2, collision_mask = 16（被玩家攻击检测）
#   - EnemyHitBox：collision_layer = 32（检测玩家 HurtBox，造成 1 点伤害）
extends Area2D
class_name BossGhostFire

enum GhostState { IDLE, FLY_TO_TARGET }

## 到达目标坐标（聚集完成）时发出，BOSS 用于统计已聚集的火焰数
signal reached_target(fire: BossGhostFire)
## 火焰结束时发出（到达聚集点 / 被玩家消灭 / 飞出屏幕销毁），
## BOSS 据此判断屏幕中是否还有活着的火焰，全部结束即可立即结算
signal finished(fire: BossGhostFire)

## 生成后原地待机时间（秒），默认 0 表示立即飞向目标
@export var idle_time: float = 0.0
## 飞向目标坐标的速度（像素/秒），慢慢聚集
@export var fly_speed: float = 80.0
## 到达目标坐标的判定距离（像素）
@export var reach_threshold: float = 6.0
## 最大血量
@export var max_hp: int = 1
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 死亡/消失动画名
@export var death_anim: String = "death"

var _state: int = GhostState.IDLE
var _idle_timer: float = 0.0
var _target_pos: Vector2 = Vector2.ZERO
var _has_target: bool = false
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


## 初始化：传入目标坐标（BOSS 调用规范）：
##    fire = BLUE_GHOST_FIRE_SCENE.instantiate()
##    fire.set_idle_time(1.0)                       # 可选：设置出现后待机时间
##    fire.set_fly_speed(120.0)                     # 可选：设置飞行速度
##    fire.global_position = marker.global_position # 生成点
##    fire.initialize(marker5.global_position)      # 传入聚集目标坐标
##    get_tree().current_scene.add_child(fire)
func initialize(target_pos: Vector2) -> void:
	_target_pos = target_pos
	_has_target = true
	# idle_time 为 0 时直接开始飞向目标
	if idle_time <= 0.0:
		_state = GhostState.FLY_TO_TARGET
		anim.play("fly")


## 接口：设置出现后原地待机的时间（秒），须在 initialize() 之前调用
func set_idle_time(t: float) -> void:
	idle_time = maxf(0.0, t)


## 接口：设置飞向目标坐标的速度（像素/秒），须在 initialize() 之前调用
func set_fly_speed(s: float) -> void:
	fly_speed = s


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _state:
		GhostState.IDLE:
			_update_idle(delta)
		GhostState.FLY_TO_TARGET:
			_update_fly_to_target(delta)


# ==================== 待机（原位不动） ====================

func _update_idle(delta: float) -> void:
	_idle_timer -= delta
	if _idle_timer <= 0.0:
		_state = GhostState.FLY_TO_TARGET
		anim.play("fly")


# ==================== 飞向目标坐标（慢慢聚集） ====================

func _update_fly_to_target(delta: float) -> void:
	if not _has_target:
		return
	var diff = _target_pos - global_position
	if diff.length() <= reach_threshold:
		_on_reached_target()
		return
	var dir = diff.normalized()
	global_position += dir * fly_speed * delta
	anim.flip_h = dir.x < 0


## 到达目标坐标（聚集完成）→ 通知 BOSS，然后静默消失（不播放死亡动画/音效）
## 只有被玩家攻击打死时才播放死亡动画和音效（见 _die()）
func _on_reached_target() -> void:
	if _is_dead:
		return
	_is_dead = true
	_state = GhostState.IDLE
	reached_target.emit(self)
	finished.emit(self)
	# 关闭所有碰撞框，静默销毁（世界消失，不播放死亡动画/音效）
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	enemy_hitbox.set_deferred("monitoring", false)
	enemy_hitbox.set_deferred("monitorable", false)
	set_process(false)
	queue_free()


# ==================== 受伤 → 死亡（与 ghost_fire 一致） ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_hp -= amount
	if _hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	finished.emit(self)
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
		finished.emit(self)
		queue_free()
