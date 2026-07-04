extends Node2D

@export var spawn_count: int = 1
@export var spawn_offset_x: float = 30.0
@export var spawn_offset_y: float = 0.0
@export var one_shot: bool = true
@export var cooldown_time: float = 5.0

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
	var scene = preload("res://scenes/enemy/l2/chaser_monster.tscn")
	var spawn_origin = spawn_position.global_position

	for i in range(spawn_count):
		var enemy = scene.instantiate()
		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = spawn_origin + Vector2(offset_x, spawn_offset_y)
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
