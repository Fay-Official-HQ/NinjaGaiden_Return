extends Node2D
class_name BossSpawner3

@export var one_shot: bool = true

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
	var scene = preload("res://scenes/enemy/boss/l3/Boss_3.tscn")
	var boss = scene.instantiate()
	boss._spawn_point = spawn_position.global_position
	boss.appear_target_pos = spawn_position.global_position
	var enemys = get_tree().current_scene.get_node_or_null("enemys")
	if enemys:
		enemys.add_child(boss)
	else:
		get_tree().current_scene.add_child(boss)
	if one_shot:
		queue_free()
