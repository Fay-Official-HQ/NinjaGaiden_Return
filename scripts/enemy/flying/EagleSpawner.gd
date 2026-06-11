extends Node2D


## ============================================================
##  EagleSpawner —— 老鹰生成器
## ============================================================
##
##  功能：玩家走进 TriggerArea 区域时，在 SpawnPosition 位置生成一群老鹰。
##
##  场景结构：
##    EagleSpawner (Node2D)
##    ├─ TriggerArea (Area2D)        ← 碰撞框拖成触发区域
##    │   └─ CollisionShape2D
##    └─ SpawnPosition (Marker2D)    ← 十字标记，拖到生成位置
##
##  在关卡中的用法：
##    1. 把 eagle_spawner.tscn 拖入关卡场景
##    2. 右键 EagleSpawner 实例 → Editable Children（可编辑子节点）
##    3. 拖拽 TriggerArea 的碰撞框调整触发范围
##    4. 拖拽 SpawnPosition 十字标记到老鹰出现的位置
##    5. 在 Inspector 中调整生成数量、冷却等参数
##    6. 改完后自动保存，无需额外操作
##
##  注意：老鹰会自动面向玩家俯冲，不需要设置飞行方向。
##        每只老鹰会复制自己的 data 资源，不会污染 EagleData.tres 原文件
## ============================================================


@export var spawn_count: int = 1             # 一次生成几只老鹰
@export var spawn_offset_x: float = 0.0      # 老鹰之间的横向间距（像素）
@export var spawn_offset_y: float = 0.0      # 老鹰之间的垂直偏移（像素）
@export var one_shot: bool = true            # true=触发一次就消失，false=可重复触发
@export var cooldown_time: float = 5.0       # 重复触发的冷却时间（秒）


var _can_spawn: bool = true                  # 是否可以触发（冷却时 false）

@onready var trigger_area: Area2D = $TriggerArea
@onready var spawn_position: Node2D = $SpawnPosition


func _ready() -> void:
	trigger_area.body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not _can_spawn:
		return
	if not body.is_in_group("player"):
		return

	_can_spawn = false
	call_deferred("_do_spawn")


func _do_spawn() -> void:
	var eagle_scene = preload("res://scenes/enemy/l1/eagle_enemy.tscn")
	var spawn_origin = spawn_position.global_position

	for i in range(spawn_count):
		var eagle = eagle_scene.instantiate()

		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		eagle.global_position = spawn_origin + Vector2(offset_x, spawn_offset_y)

		eagle.data = eagle.data.duplicate()

		get_tree().current_scene.add_child(eagle)

	if one_shot:
		queue_free()
	else:
		var timer = Timer.new()
		add_child(timer)
		timer.one_shot = true
		timer.wait_time = cooldown_time
		timer.timeout.connect(func():
			_can_spawn = true
			timer.queue_free()
		)
		timer.start()
