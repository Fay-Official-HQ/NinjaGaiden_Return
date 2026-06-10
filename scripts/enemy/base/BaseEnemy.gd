# res://scripts/enemy/base/BaseEnemy.gd
# 小怪基类：所有小怪共用受伤、死亡、朝向逻辑
class_name BaseEnemy
extends CharacterBody2D

# ── 子类场景必须包含的节点 ──
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox

# ── 数据资源（由子类场景在 Inspector 中绑定） ──
@export var data: BaseEnemyData

# ── 运行时状态 ──
var is_dead: bool = false
var facing_right: bool = true


func _ready() -> void:
	hurtbox.took_damage.connect(_on_took_damage)


# ==================== 受击 → 死亡流程 ====================

# 玩家攻击状态每帧 polling 检测到 HurtBox 后，会调用
# HurtBox.take_damage() → 发出 took_damage 信号
func _on_took_damage(_amount: int) -> void:
	if is_dead:
		return
	_die()


# 统一死亡处理
func _die() -> void:
	is_dead = true

	AudioManager.play_sound(data.death_sound)

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)

	anim.play(data.death_anim)
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


# ==================== 工具方法 ====================

# 翻转朝向
func _set_facing(right: bool) -> void:
	facing_right = right
	anim.flip_h = not right


# ==================== 子类可覆盖 ====================

# 如果某些子类需要用 area_entered 做特殊逻辑（如检测玩家进入攻击范围），
# 可在此覆盖
func _on_hurtbox_area_entered(area: Area2D) -> void:
	pass
