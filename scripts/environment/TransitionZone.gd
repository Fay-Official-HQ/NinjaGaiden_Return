extends Area2D

class_name TransitionZone

## 目标场景路径（在 Inspector 中拖入 .tscn）
@export var target_scene: String = ""

## 进入目标场景后玩家出现的入口点（对应关卡中的 Marker2D 节点名）
@export var spawn_point: String = "default"


func _ready() -> void:
	body_entered.connect(_on_body_entered)



func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and target_scene != "":
		LevelManager.goto_level(target_scene, spawn_point)
