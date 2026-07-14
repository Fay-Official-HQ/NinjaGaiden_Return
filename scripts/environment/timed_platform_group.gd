# TimedPlatformGroup.gd
extends Area2D
class_name TimedPlatformGroup
##出现次序
@export var appear_order: Array[int] = [0, 1, 2, 3]
##出现间隔
@export var appear_interval: float = 0.3
##每个持续时间
@export var platform_lifetime: float = 2.0
##循环间隔
@export var cycle_interval: float = 3.0
##是否循环
@export var loop: bool = true
##淡入淡出时间
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
			_set_collision_recursive(child, false)

	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player and not _cycle_active and _platforms.size() > 0:
		_cycle_active = true
		call_deferred("_start_cycle")


func _start_cycle() -> void:
	while _cycle_active:
		var show_count = 0
		for index in appear_order:
			if index < 0 or index >= _platforms.size():
				continue
			var platform = _platforms[index]
			_show_platform(platform)
			show_count += 1
			var timer = get_tree().create_timer(platform_lifetime)
			timer.timeout.connect(func():
				if is_instance_valid(platform):
					_hide_platform(platform)
			)
			await get_tree().create_timer(appear_interval).timeout

		if show_count == 0:
			break

		if not loop:
			while _cycle_active:
				var has_visible = false
				for p in _platforms:
					if p.visible:
						has_visible = true
						break
				if not has_visible:
					break
				await get_tree().process_frame
			_cycle_active = false
			break

		_cycle_active = false

		var has_player = false
		for body in get_overlapping_bodies():
			if body is Player:
				has_player = true
				break

		if has_player:
			_cycle_active = true
			call_deferred("_start_cycle")
			return


func _show_platform(platform: Node2D) -> void:
	platform.visible = true
	platform.modulate.a = 0.0
	AudioManager.play_sound(&"shibingxuli")
	var tween = platform.create_tween()
	tween.tween_property(platform, "modulate:a", 1.0, fade_duration)
	tween.finished.connect(func():
		if is_instance_valid(platform):
			_set_collision_recursive(platform, true)
	, CONNECT_ONE_SHOT)


func _hide_platform(platform: Node2D) -> void:
	_set_collision_recursive(platform, false)
	var tween = platform.create_tween()
	tween.tween_property(platform, "modulate:a", 0.0, fade_duration)


func _set_collision_recursive(node: Node, enabled: bool) -> void:
	if node is CollisionShape2D:
		node.disabled = not enabled
	for i in node.get_child_count():
		_set_collision_recursive(node.get_child(i), enabled)
