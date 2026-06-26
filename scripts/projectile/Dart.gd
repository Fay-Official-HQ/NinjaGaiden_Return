# res://scripts/projectile/Dart.gd
# 飞镖投射物：朝固定方向飞行，碰撞玩家造成伤害，可被玩家攻击摧毁
extends Area2D
class_name Dart

## 节点引用
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D

## 运行时状态
var _direction: Vector2           # 飞行方向（单位向量）
var _data: DartData               # 数据引用
var _hp: int                      # 当前生命值


func _ready() -> void:
	# 信号一次性连接，避免重复 connect 报错
	hurtbox.took_damage.connect(_on_took_damage)
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.animation_finished.connect(_on_death_finished)

func initialize(direction: Vector2, dart_data: DartData) -> void:
	_direction = direction.normalized()
	_data = dart_data
	_hp = dart_data.max_hp

	# 应用发射角度偏移（让玩家可蹲下躲避，在 DartData 中调试）
	if _data.launch_angle_offset != 0.0:
		_direction = _direction.rotated(deg_to_rad(_data.launch_angle_offset))

	# 精灵朝向飞行方向
	anim.flip_h = _direction.x < 0
	anim.play("flying")


func _process(delta: float) -> void:
	position += _direction * _data.speed * delta


# ==================== 受击（被玩家武器击中） ====================

func _on_took_damage(_amount: int, _is_heavy: bool = false) -> void:
	_hp -= 1
	if _hp <= 0:
		AudioManager.play_sound(_data.death_sound)
		set_process(false)
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
		anim.play("death")


# ==================== 飞出屏幕销毁 ====================

func _on_screen_exited() -> void:
	queue_free()


func _on_death_finished() -> void:
	# 只有播放 death 动画播完才销毁，防止 flying 结束误触发
	if anim.animation == "death":
		queue_free()
