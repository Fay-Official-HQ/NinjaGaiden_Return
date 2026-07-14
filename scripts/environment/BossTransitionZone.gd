extends Area2D
class_name BossTransitionZone

## 目标 Boss 场景路径（在 Inspector 中拖入 .tscn）
@export var target_scene: String = ""

## 进入 Boss 场景后玩家出现的入口点
@export var spawn_point: String = "default"

## 画面渐黑 + BGM 淡出时长（秒）
@export var fade_duration: float = 2.0

## 是否已触发（防止重复触发）
var _triggered: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# 兜底：如果玩家在 _ready() 连接信号之前就已经在区域内了，
	# body_entered 不会发射，需要主动检测
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)
			return


func _on_body_entered(body: Node2D) -> void:
	if _triggered:
		return
	if not body.is_in_group("player") or target_scene.is_empty():
		return
	_triggered = true
	SceneTransition.fade_to_scene(target_scene, spawn_point, fade_duration)
