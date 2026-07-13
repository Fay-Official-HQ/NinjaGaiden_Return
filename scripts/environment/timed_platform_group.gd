# TimedPlatformGroup.gd
extends Area2D
class_name TimedPlatformGroup

@export var appear_order: Array[int] = [0, 1, 2, 3]
@export var appear_interval: float = 0.3
@export var platform_lifetime: float = 2.0
@export var cycle_interval: float = 3.0
@export var loop: bool = true
@export var fade_duration: float = 0.15

var _platforms: Array[Node2D] = []
var _cycle_active: bool = false

func _ready() -> void:
	monitoring = true
	collision_mask = 1

	for child in $SpawnPoints.get_children():
		if child is Node2D:
			_platforms.append(child)
			child.visible = false
			var col = child.get_node("StaticBody2D/CollisionShape2D")
			if col:
				col.disabled = true

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _cycle_active and _platforms.size() > 0:
		_cycle_active = true
		call_deferred("_start_cycle")


func _start_cycle() -> void:
	while _cycle_active:
		for index in appear_order:
			if index < 0 or index >= _platforms.size():
				continue
			var platform = _platforms[index]
			_show_platform(platform)
			await get_tree().create_timer(appear_interval).timeout

		await get_tree().create_timer(platform_lifetime).timeout

		for index in appear_order:
			if index < 0 or index >= _platforms.size():
				continue
			var platform = _platforms[index]
			_hide_platform(platform)
			await get_tree().create_timer(appear_interval).timeout

		if not loop:
			_cycle_active = false
			break

		await get_tree().create_timer(cycle_interval).timeout


func _show_platform(platform: Node2D) -> void:
	platform.visible = true
	platform.modulate.a = 0.0
	var col = platform.get_node("StaticBody2D/CollisionShape2D")
	if col:
		col.disabled = false
	AudioManager.play_sound(&"shibingxuli")
	var tween = platform.create_tween()
	tween.tween_property(platform, "modulate:a", 1.0, fade_duration)


func _hide_platform(platform: Node2D) -> void:
	var col = platform.get_node("StaticBody2D/CollisionShape2D")
	if col:
		col.disabled = true
	var tween = platform.create_tween()
	tween.tween_property(platform, "modulate:a", 0.0, fade_duration)
