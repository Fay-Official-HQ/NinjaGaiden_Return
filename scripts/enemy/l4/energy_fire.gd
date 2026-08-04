# res://scripts/enemy/l4/energy_fire.gd
extends Area2D
class_name EnergyFire

## EnergyFire —— BOSS4 追踪能量波投射物
## ============================================================
##  1. 朝任意方向飞行（Vector2 方向，不限于水平）
##  2. 撞到地形或玩家 → 爆炸
##  3. 不可被玩家摧毁（无 HurtBox）
##  4. 飞行中缓慢向玩家偏转弹道（追踪玩家，但不是完全跟踪，直线运动为主）
##  5. 爆炸播放 death 动画 + 音效，并开启 ExplosionHitBox 造成范围伤害
##  6. 参数全部写在代码里（无数据驱动），可在 Inspector 调试
## ============================================================
## 【调用规范】（调用方必须遵守此顺序）：
##    fire = scene.instantiate()
##    fire.set_damage(dmg)             # 可选：默认 1；BOSS 按收集火焰数传 2~8
##    fire.initialize(dir, speed)      # 1. 先设方向和速度
##    fire.global_position = spawn_pos # 2. 再设位置
##    add_child(fire)                  # 3. 最后加入场景
## ============================================================

# ==================== 导出参数（Inspector 调试） ====================

## 飞行速度（仅 Inspector 默认值，运行时由 initialize() 覆盖）
@export var default_speed: float = 300.0
## 弹道追踪强度：每秒钟可向玩家偏转的最大角度（度），越大越像跟踪
@export var homing_turn_rate: float = 45.0
## 爆炸伤害（默认 1，运行时由 set_damage() 覆盖为 2~8）
@export var explosion_damage: int = 1
## 爆炸音效
@export var explosion_sound: StringName = &"leidian"
## 未命中时最长存活时间（秒），到时自动爆炸，防止无限追踪
@export var lifetime: float = 10.0

# ==================== 运行时状态 ====================

## 当前实际飞行速度（由 initialize() 设置）
var speed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _is_exploding: bool = false
var _life_timer: float = 0.0

# ==================== 节点引用 ====================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _explosion_hitbox: Area2D = $ExplosionHitBox
@onready var _notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	_notifier.screen_exited.connect(_on_screen_exited)
	_life_timer = lifetime

	# 爆炸范围伤害框初始关闭，爆炸时才开启
	_explosion_hitbox.set_deferred("monitoring", false)
	_explosion_hitbox.set_deferred("monitorable", false)
	# 同步 set_damage() 设置的伤害：set_damage 可能在本节点进树前被调用，
	# 那时 @onready 的 _explosion_hitbox 尚未就绪，这里补一次同步保证爆炸伤害生效
	_explosion_hitbox.damage = explosion_damage

	# 播放飞行动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("flying"):
		_sprite.play("flying")


## 初始化：方向向量 + 速度（在 add_child 之前调用）
func initialize(dir: Vector2, initial_speed: float) -> void:
	_direction = dir.normalized()
	speed = initial_speed

	# 根据水平方向翻转精灵
	if _sprite:
		_sprite.flip_h = (_direction.x < 0)


## 设置爆炸伤害（BOSS 按收集的火焰能量调用：2~8 点）
func set_damage(d: int) -> void:
	explosion_damage = d
	if _explosion_hitbox:
		_explosion_hitbox.damage = d


# ==================== 每帧移动 ====================

func _process(delta: float) -> void:
	if _is_exploding:
		return
	_homing_update(delta)
	position += _direction * speed * delta
	_life_timer -= delta
	if _life_timer <= 0.0:
		_trigger_explosion()


## 弹道追踪：每帧把飞行方向朝玩家缓慢偏转（有限转角，不是完全跟踪）
func _homing_update(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var to_player = (player.global_position - global_position).normalized()
	var angle_diff = wrapf(to_player.angle() - _direction.angle(), -PI, PI)
	var max_turn = deg_to_rad(homing_turn_rate) * delta
	_direction = _direction.rotated(clampf(angle_diff, -max_turn, max_turn))


# ==================== 爆炸触发（2 种途径） ====================

## 途径1：撞到地形（StaticBody2D）或玩家身体（CharacterBody2D）
func _on_body_entered(_body: Node2D) -> void:
	_trigger_explosion()


## 途径2：撞到玩家受击框（HurtBox Area2D）
func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		_trigger_explosion()


## 飞出屏幕：未爆炸时直接销毁
func _on_screen_exited() -> void:
	if not _is_exploding:
		queue_free()


# ==================== 爆炸执行 ====================

func _trigger_explosion() -> void:
	if _is_exploding:
		return
	_is_exploding = true
	set_process(false)

	# 播放爆炸音效
	if explosion_sound != &"":
		AudioManager.play_sound(explosion_sound)

	# 开启爆炸范围伤害框
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", true)
		_explosion_hitbox.set_deferred("monitorable", true)

	# 播放爆炸动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		_sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		# 没有死亡动画，直接清理
		_cleanup()


func _on_death_anim_finished() -> void:
	_cleanup()


func _cleanup() -> void:
	# 关闭爆炸框并销毁
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)
	queue_free()
