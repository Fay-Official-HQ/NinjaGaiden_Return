extends CharacterBody2D
class_name Landmine

## Landmine —— 地雷
## ============================================================
##  1. 静止放置，播放 idle 待机动画
##  2. 玩家进入 DetectRange 触发区域 → 引爆
##  3. 爆炸：播放 leidian 音效，开启 ExplosionHitBox 范围伤害
##  4. 播放 death 死亡动画，结束后关闭 ExplosionHitBox 并销毁
## ============================================================

# ==================== 导出参数（Inspector 调试） ====================

## 重力加速度（保证贴地，不浮空）
const GRAVITY: float = 980.0

## 爆炸伤害
@export var explosion_damage: int = 3
## 爆炸音效
@export var death_sound: StringName = &"leidian"

# ==================== 运行时状态 ====================

var _is_exploding: bool = false

# ==================== 节点引用 ====================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _detect_range: Area2D = $DetectRange
@onready var _explosion_hitbox: Area2D = $ExplosionHitBox


# ==================== 每帧物理：重力贴地 ====================

func _physics_process(delta: float) -> void:
	if _is_exploding:
		return
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()


func _ready() -> void:
	# 触发区域：玩家进入即引爆
	if _detect_range:
		_detect_range.body_entered.connect(_on_body_entered)

	# 确保爆炸框初始关闭
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)

	# 播放待机动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("idle"):
		_sprite.play("idle")


# ==================== 爆炸触发 ====================

## 玩家进入触发区域
func _on_body_entered(_body: Node2D) -> void:
	_trigger_explosion()


# ==================== 爆炸执行 ====================

func _trigger_explosion() -> void:
	if _is_exploding:
		return
	_is_exploding = true

	# 播放爆炸音效
	if death_sound != &"":
		AudioManager.play_sound(death_sound)

	# 关闭触发区域，防止重复引爆
	if _detect_range:
		_detect_range.set_deferred("monitoring", false)

	# 开启爆炸范围伤害框
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", true)
		_explosion_hitbox.set_deferred("monitorable", true)

	# 播放死亡动画，结束后清理
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
