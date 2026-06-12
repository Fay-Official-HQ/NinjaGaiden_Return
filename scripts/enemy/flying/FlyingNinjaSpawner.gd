extends Node2D


## ============================================================
##  FlyingNinjaSpawner —— 飞天忍者生成器
## ============================================================
##
##  功能：玩家走进 TriggerArea 区域时，在 SpawnPosition 位置生成飞天忍者。
##
##  场景结构：
##    FlyingNinjaSpawner (Node2D)
##    ├─ TriggerArea (Area2D)        ← 碰撞框拖成触发区域
##    │   └─ CollisionShape2D
##    └─ SpawnPosition (Marker2D)    ← 十字标记，拖到生成位置
##
##  使用方式同 EagleSpawner。
## ============================================================


@export var spawn_count: int = 1             # 一次生成几个
@export var spawn_offset_x: float = 16.0     # 横向间距（像素）
@export var spawn_offset_y: float = 0.0      # 垂直偏移（像素）
@export var one_shot: bool = true            # true=触发一次就消失
@export var cooldown_time: float = 5.0       # 重复触发的冷却时间（秒）


var _can_spawn: bool = true

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
	var scene = preload("res://scenes/enemy/l1/flying_ninja.tscn")
	var origin = spawn_position.global_position

	for i in range(spawn_count):
		var enemy = scene.instantiate()

		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = origin + Vector2(offset_x, spawn_offset_y)

		enemy.data = enemy.data.duplicate()

		get_tree().current_scene.add_child(enemy)

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
