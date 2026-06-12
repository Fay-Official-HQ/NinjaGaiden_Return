extends Node2D


## ============================================================
##  ChaserNinjaSpawner —— 追击拳手忍者生成器
## ============================================================
##
##  功能：玩家走进 TriggerArea 区域时，在 SpawnPosition 位置生成一群追击拳手忍者。
##
##  场景结构：
##    ChaserNinjaSpawner (Node2D)
##    ├─ TriggerArea (Area2D)        ← 碰撞框拖成触发区域
##    │   └─ CollisionShape2D
##    └─ SpawnPosition (Marker2D)    ← 十字标记，拖到生成位置
##
##  在关卡中的用法：
##    1. 把 chaser_ninja_spawner.tscn 拖入关卡场景
##    2. 右键实例 → Editable Children（可编辑子节点）
##    3. 拖拽 TriggerArea 的碰撞框调整触发范围
##    4. 拖拽 SpawnPosition 十字标记到忍者出现的位置
##    5. 在 Inspector 中调整生成数量、方向等参数
##    6. 改完后自动保存，无需额外操作
##
##  注意：每个忍者的 data 资源会被独立复制，不会污染原 .tres 文件
## ============================================================


@export var spawn_count: int = 1             # 一次生成几个追击忍者
@export var spawn_direction: int = -1        # -1 向左追击，1 向右追击
@export var spawn_offset_x: float = 30.0     # 忍者之间的横向间距（像素）
@export var spawn_offset_y: float = 0.0      # 忍者之间的垂直偏移（像素）
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
	var scene = preload("res://scenes/enemy/l1/chaser_ninja.tscn")
	var spawn_origin = spawn_position.global_position

	for i in range(spawn_count):
		var enemy = scene.instantiate()

		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = spawn_origin + Vector2(offset_x, spawn_offset_y)

		# 复制数据资源，避免污染原文件
		enemy.data = enemy.data.duplicate()
		# 设置追击方向（true=面朝右追击，false=面朝左追击）
		enemy.facing_right = (spawn_direction == 1)

		get_tree().current_scene.add_child(enemy)
		# 加入场景后 @onready 变量已就绪，再设置精灵朝向
		enemy.anim.flip_h = not (spawn_direction == 1)

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
