extends Area2D
class_name BossTransitionZone

## 目标 Boss 场景路径（在 Inspector 中拖入 .tscn）
@export var target_scene: String = ""

## 进入 Boss 场景后玩家出现的入口点
@export var spawn_point: String = "default"

## 画面渐黑 + BGM 淡出时长（秒）
@export var fade_duration: float = 2.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or target_scene.is_empty():
		return
	SceneTransition.fade_to_scene(target_scene, spawn_point, fade_duration)
