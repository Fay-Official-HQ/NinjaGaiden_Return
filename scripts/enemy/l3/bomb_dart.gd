extends Area2D
class_name BombDart

## BombDart —— 爆炸飞镖
## ============================================================
##  1. 朝任意方向飞行（Vector2 方向）
##  2. 撞到玩家/地形/被攻击 → 爆炸
##  3. 爆炸中关闭 HurtBox，开启 ExplosionHitBox（爆炸范围伤害）
##  4. 死亡动画结束后关闭 ExplosionHitBox 并销毁
## ============================================================
##
## 【调用规范】（调用方必须遵守此顺序）：
##    dart = scene.instantiate()
##    dart.initialize(dir, speed)       # 1. 先设方向和速度
##    dart.global_position = spawn_pos  # 2. 再设位置
##    add_child(dart)                  # 3. 最后加入场景
## ============================================================

# ==================== 导出参数（Inspector 调试） ====================

## 初始飞行速度（仅 Inspector 默认值，运行时由 initialize() 覆盖）
@export var default_speed: float = 300.0
## 生命值
@export var hp: int = 1
## 爆炸伤害
@export var explosion_damage: int = 3
## 爆炸音效
@export var death_sound: StringName = &"leidian"

# ==================== 运行时状态 ====================

## 当前实际飞行速度（由 initialize() 设置）
var speed: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
var _is_exploding: bool = false

# ==================== 节点引用 ====================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _explosion_hitbox: Area2D = $ExplosionHitBox
@onready var _hurtbox: Area2D = $HurtBox
@onready var _notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	# 信号在 _ready 中统一连接（依赖调用方先 initialize 再 add_child 的顺序保证安全）
	body_entered.connect(_on_body_entered)
	_notifier.screen_exited.connect(_on_screen_exited)

	# 连接受伤信号
	if _hurtbox and _hurtbox.has_signal("took_damage"):
		_hurtbox.took_damage.connect(_on_took_damage)

	# 确保爆炸框初始关闭
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)

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


# ==================== 每帧移动 ====================

func _process(delta: float) -> void:
	if _is_exploding:
		return
	position += _direction * speed * delta


# ==================== 爆炸触发（3 种途径） ====================

## 途径1：撞到地形或玩家身体
func _on_body_entered(_body: Node2D) -> void:
	_trigger_explosion()


## 途径2：被玩家攻击摧毁
func _on_took_damage(_damage: int, _is_heavy: bool = false) -> void:
	if _is_exploding:
		return
	hp -= 1
	if hp <= 0:
		_trigger_explosion()


## 途径3：飞出屏幕
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
	if death_sound != &"":
		AudioManager.play_sound(death_sound)

	# 关闭受击框（不再接受玩家攻击）
	if _hurtbox:
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)

	# 开启爆炸范围伤害框
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", true)
		_explosion_hitbox.set_deferred("monitorable", true)

	# 播放死亡动画
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
