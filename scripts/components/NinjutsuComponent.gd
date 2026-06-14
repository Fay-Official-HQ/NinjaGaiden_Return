extends Node

class_name NinjutsuComponent

signal mp_changed(current_mp: int)
signal ninjutsu_switched(index: int, name: String)

@export var mp_cost: int = 1
@export var ninjutsu_names: Array[String] = ["火焰", "火球", "棱刃", "回旋镖"]

var current_mp: int = 0
var current_ninjutsu_index: int = 0

var _fire_scene: PackedScene = preload("res://scenes/ninjutsu/fire_ninjutsu.tscn")
var _fireball_scene: PackedScene = preload("res://scenes/ninjutsu/fireball_ninjutsu.tscn")
var _edge_blade_scene: PackedScene = preload("res://scenes/ninjutsu/edge_blade_ninjutsu.tscn")
var _boomerang_scene: PackedScene = preload("res://scenes/ninjutsu/boomerang_ninjutsu.tscn")

func _ready() -> void:
	var player_data = _get_player_data()
	if player_data:
		current_mp = player_data.initial_mp

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("switch_ninjutsu"):
		switch_ninjutsu()

func _get_player_data() -> PlayerData:
	var player = get_parent().owner as Player
	if not player:
		return null
	return player.data

func add_mp(amount: int) -> void:
	var max_mp = _get_player_data().max_mp
	current_mp = clampi(current_mp + amount, 0, max_mp)
	mp_changed.emit(current_mp)

func switch_ninjutsu() -> void:
	current_ninjutsu_index = (current_ninjutsu_index + 1) % ninjutsu_names.size()
	var ninjutsu_name = ninjutsu_names[current_ninjutsu_index]
	print("切换忍术：", ninjutsu_name)
	ninjutsu_switched.emit(current_ninjutsu_index, ninjutsu_name)

func cast_ninjutsu(facing_override: float = 0.0) -> void:
	if current_mp < mp_cost:
		print("MP不足，无法释放")
		UIManager.show_message("忍術不足！")
		return

	current_mp -= mp_cost
	mp_changed.emit(current_mp)

	match current_ninjutsu_index:
		0:
			_cast_fire(facing_override)
		1:
			_cast_fireball(facing_override)
		2:
			_cast_edgeblade(facing_override)
		3:
			_cast_boomerang(facing_override)

func _get_player() -> Player:
	return get_parent().owner as Player

func _get_dir(facing_override: float) -> float:
	# facing_override != 0 表示墙上释放，由 WallState 指定方向
	if facing_override != 0:
		return 1.0 if facing_override > 0 else -1.0
	var player = _get_player()
	return 1.0 if player.facing_direction > 0 else -1.0

func _cast_fire(facing_override: float = 0.0) -> void:
	AudioManager.play_sound(&"renshuhuoyan")
	print("释放忍术：火焰")
	var player = _get_player()
	if not player:
		return
	var dir = _get_dir(facing_override)
	var base_pos = player.global_position + Vector2(dir * 20, -8)
	var base_angle = Vector2(dir, -1).normalized()
	var offsets = [-15.0, 0.0, 15.0]

	for offset in offsets:
		var proj = _fire_scene.instantiate() as FireProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_fireball(facing_override: float = 0.0) -> void:
	print("释放忍术：火球")
	AudioManager.play_sound(&"renshuhuoqiu")
	var player = _get_player()
	var dir = _get_dir(facing_override)
	var base_pos = player.global_position + Vector2(dir * 20, 8)
	var base_angle = Vector2(dir, 1).normalized()
	var offsets = [-15.0, 0.0, 15.0]

	for offset in offsets:
		var proj = _fireball_scene.instantiate() as FireballProjectile
		proj.set_direction(base_angle.rotated(deg_to_rad(offset)))
		proj.global_position = base_pos + Vector2(0, offset * 0.3)
		get_tree().current_scene.add_child(proj)

func _cast_edgeblade(_facing_override: float = 0.0) -> void:
	AudioManager.play_sound(&"renshulengren")
	print("释放忍术：棱刃")
	var player = _get_player()
	if not player:
		return

	var up_blade := _edge_blade_scene.instantiate() as EdgeBlade
	up_blade.player_ref = player
	up_blade.initial_direction = Vector2.UP
	up_blade.global_position = player.global_position
	get_tree().current_scene.add_child(up_blade)

	var down_blade := _edge_blade_scene.instantiate() as EdgeBlade
	down_blade.player_ref = player
	down_blade.initial_direction = Vector2.DOWN
	down_blade.global_position = player.global_position
	get_tree().current_scene.add_child(down_blade)

func _cast_boomerang(facing_override: float = 0.0) -> void:
	print("释放忍术：回旋镖")
	AudioManager.play_sound(&"renshubiao")
	var player = _get_player()
	if not player:
		return

	var boomerang := _boomerang_scene.instantiate() as Boomerang
	boomerang.player_ref = player
	boomerang.facing_override = facing_override
	boomerang.global_position = player.global_position
	get_tree().current_scene.add_child(boomerang)
