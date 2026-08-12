extends Node2D
class_name AkSoldierSpawner

## AK士兵生成器 —— 玩家进入 TriggerArea 触发，在 SpawnPosition 处生成士兵
## ============================================================
##  1. 可选择生成的士兵类型：类型1（chaser_AKsoldier）/ 类型2（chaser_AKsoldier2）
##  2. 可设置一轮点射的子弹数量（1~5），会自动传给生成的士兵
##  3. 支持批量生成、是否一次性、冷却后再次生成
## ============================================================

# ── 可调数据（Inspector 可调） ──
## 生成的士兵类型：1 = 类型1（无蹲伏切换），2 = 类型2（有蹲伏切换）
@export_enum("类型1：chaser_AKsoldier", "类型2：chaser_AKsoldier2") var soldier_type: int = 1
## 士兵一轮点射的子弹数量（1~5）
@export_range(1, 5) var burst_count: int = 3
## 一次触发生成的士兵数量
@export var spawn_count: int = 1
## 多个士兵生成时的横向间距（像素）
@export var spawn_offset_x: float = 30.0
## 多个士兵生成时的纵向偏移（像素）
@export var spawn_offset_y: float = 0.0
## 是否一次性生成（生成后删除生成器）
@export var one_shot: bool = true
## 非一次性时，再次生成的冷却时间（秒）
@export var cooldown_time: float = 5.0

# ── 士兵场景 ──
const SOLDIER_1_SCENE: PackedScene = preload("res://scenes/enemy/l5/chaser_AKsoldier.tscn")
const SOLDIER_2_SCENE: PackedScene = preload("res://scenes/enemy/l5/chaser_AKsoldier2.tscn")

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
	var scene: PackedScene = SOLDIER_1_SCENE if soldier_type == 1 else SOLDIER_2_SCENE
	var spawn_origin = spawn_position.global_position

	for i in range(spawn_count):
		var enemy = scene.instantiate()
		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = spawn_origin + Vector2(offset_x, spawn_offset_y)
		enemy.burst_count = burst_count
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
