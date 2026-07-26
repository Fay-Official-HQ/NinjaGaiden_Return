extends Node2D

@export var spawn_count: int = 1
@export var spawn_offset_x: float = 16.0
@export var spawn_offset_y: float = 0.0
@export var one_shot: bool = true
@export var cooldown_time: float = 5.0

var _can_spawn: bool = true

@onready var trigger_area: Area2D = $TriggerArea
@onready var spawn_position: Node2D = $SpawnPosition
@onready var target_position: Node2D = $TargetPosition


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
	var scene = preload("res://scenes/enemy/l3/white_ninja.tscn")
	var origin = spawn_position.global_position
	var target = target_position.global_position

	for i in range(spawn_count):
		var enemy = scene.instantiate() as WhiteNinja
		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = origin + Vector2(offset_x, spawn_offset_y)
		enemy.target_landing_x = target.x
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
