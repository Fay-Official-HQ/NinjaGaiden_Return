extends Node2D

## RedEliteNinjaSpawner —— 红忍专属生成器
## ============================================================
##  1. 玩家进入 TriggerArea 触发
##  2. 生成 1 个 RedEliteNinja，1 秒渐显
##  3. 完全显现后才开始战斗
## ============================================================

@export var one_shot: bool = true
@export var cooldown_time: float = 5.0
## 敌人最大生命值（默认 2，-1 表示使用敌人自身的默认值）
@export var max_hp: int = -1

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
	var scene = preload("res://scenes/enemy/l3/RedEliteNinja.tscn")
	var enemy = scene.instantiate() as RedEliteNinja
	enemy.global_position = spawn_position.global_position

	# 进入显现状态（强制待机，不响应玩家探测）
	enemy.start_appearing()
	# 覆盖生命值（默认 -1 时使用敌人自身设置）
	if max_hp > 0:
		enemy.max_hp = max_hp
	get_tree().current_scene.add_child(enemy)

	# 1 秒渐显 → 结束显现，开始战斗
	var tween = enemy.create_tween()
	tween.tween_property(enemy, "modulate", Color.WHITE, 1.0)
	tween.finished.connect(func():
		enemy.finish_appearing()
	)

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
