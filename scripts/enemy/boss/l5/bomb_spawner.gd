extends Node
class_name BombSpawner

## 覆盖式轰炸生成器 —— 独立于 Boss 状态运行
## Boss 只负责播放召唤动画，生成器挂到场景后按间隔落弹，直到时长结束自毁。
## 范围由关卡 hongzha 节点下的 Marker2D / Marker2D2 两个坐标框定。

## 导弹场景
var missile_scene: PackedScene
## 范围角点 A（Marker2D 全局坐标）
var range_a: Vector2
## 范围角点 B（Marker2D2 全局坐标）
var range_b: Vector2
## 导弹生成间隔（秒）
var interval: float = 0.3
## 轰炸总持续时间（秒）
var duration: float = 5.0
## 导弹下落速度（像素/秒）
var missile_speed: float = 500.0
## 导弹爆炸伤害
var missile_damage: int = 3

var _timer: float = 0.0
var _spawn_timer: float = 0.0


func _process(delta: float) -> void:
	_timer += delta
	_spawn_timer += delta
	# 轰炸持续期间按间隔落弹
	while _spawn_timer >= interval and _timer <= duration:
		_spawn_timer -= interval
		_spawn_missile()
	# 时长结束自毁
	if _timer >= duration:
		queue_free()


## 在两个 Marker 框定的矩形范围内随机生成一枚从天而降的导弹
func _spawn_missile() -> void:
	if not missile_scene:
		return
	var missile: BombMissile = missile_scene.instantiate()
	get_tree().current_scene.add_child(missile)
	missile.global_position = Vector2(
		randf_range(minf(range_a.x, range_b.x), maxf(range_a.x, range_b.x)),
		randf_range(minf(range_a.y, range_b.y), maxf(range_a.y, range_b.y))
	)
	# 爆炸伤害由数据驱动控制
	var hitbox = missile.get_node_or_null("ExplosionHitBox")
	if hitbox and "damage" in hitbox:
		hitbox.damage = missile_damage
	missile.initialize(Vector2.DOWN, missile_speed)
