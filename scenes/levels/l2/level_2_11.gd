extends Node2D

const CHUNK_WIDTH := 480
const SCROLL_SPEED := 40.0

var _chunk_scenes: Array[PackedScene] = []
var _active_chunks: Array[Node] = []
var _is_boss_phase := false
var _is_transitioning := false
var _boss_ref: Node2D


func _ready() -> void:
	SceneTransition.clear_overlay_safe()
	AudioManager.play_sound(&"wind1")

	var cam = $Player/Camera2D
	cam.set_follow_x(true)
	cam.set_follow_y(false)
	cam.set_bounds(0, 480, -1, -1)
	cam.offset.y = 135

	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_01.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_02.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_03.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_04.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_05.tscn"))

	$Player.global_position.x = 80

	var statue = get_node_or_null("enemys/BossStatue")
	if statue and statue.has_signal("statue_destroyed"):
		statue.statue_destroyed.connect(_on_statue_destroyed)
		print("【Boss房间】已连接雕像信号")
	else:
		print("【Boss房间】未找到雕像节点")


func _process(delta: float) -> void:
	if not _is_boss_phase:
		return

	var cam = $Player/Camera2D
	cam.fixed_x += SCROLL_SPEED * delta

	var cam_left = cam.global_position.x - 240
	var cam_right = cam.global_position.x + 240

	while _active_chunks.size() > 1:
		var first = _active_chunks[0]
		if first.position.x + CHUNK_WIDTH < cam_left - CHUNK_WIDTH:
			first.queue_free()
			_active_chunks.remove_at(0)
		else:
			break

	if _active_chunks.size() > 0:
		var last = _active_chunks[-1]
		if last.position.x + CHUNK_WIDTH < cam_right + CHUNK_WIDTH * 2:
			_spawn_chunk(last.position.x + CHUNK_WIDTH)


func _spawn_chunk(x: float, idx: int = -1) -> void:
	if idx < 0 or idx >= _chunk_scenes.size():
		idx = randi() % _chunk_scenes.size()
	var chunk = _chunk_scenes[idx].instantiate()
	chunk.position.x = x
	$Map/InfiniteLevel/Chunks.add_child(chunk)
	_active_chunks.append(chunk)


func _on_statue_destroyed(spawn_pos: Vector2) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true

	_spawn_boss(spawn_pos)
	_spawn_fire_wall()

	for i in range(1, 4):
		_spawn_chunk(i * CHUNK_WIDTH)

	_is_transitioning = false

	connect_fire_wall()


func _spawn_boss(hint_pos: Vector2 = Vector2.INF) -> void:
	var pos = get_node_or_null("BossSpawnPosition") as Marker2D
	var spawn_at: Vector2
	if pos:
		spawn_at = pos.global_position
	elif hint_pos != Vector2.INF:
		spawn_at = hint_pos
	else:
		return

	var scene = preload("res://scenes/enemy/boss/l2/Boss_2.tscn")
	var boss = scene.instantiate()
	boss._spawn_point = spawn_at
	get_tree().current_scene.add_child(boss)
	_boss_ref = boss


func _start_auto_scroll() -> void:
	var cam = $Player/Camera2D
	cam.fixed_x = cam.global_position.x
	cam.set_follow_x(false)
	cam.set_follow_y(false)
	cam.fixed_y = cam.global_position.y


func _spawn_fire_wall() -> void:
	print("【Boss房间】激活火墙")
	var fire_wall = get_node_or_null("FireWall")
	if fire_wall:
		print("【Boss房间】找到 FireWall 节点:", fire_wall.name)
		if fire_wall.has_method("activate"):
			fire_wall.activate()
			print("【Boss房间】火墙已激活")
		else:
			print("【Boss房间】FireWall 节点没有 activate 方法")
	else:
		print("【Boss房间】场景中没有 FireWall 节点，动态创建")
		var new_wall = preload("res://scenes/enemy/boss/l2/FireWall.tscn").instantiate()
		add_child(new_wall)
		if new_wall.has_method("activate"):
			new_wall.activate()


func connect_fire_wall() -> void:
	var fire_wall = get_node_or_null("FireWall")
	if fire_wall and fire_wall.has_signal("enter_completed"):
		if not fire_wall.enter_completed.is_connected(_start_boss_battle):
			fire_wall.enter_completed.connect(_start_boss_battle)


func _start_boss_battle() -> void:
	print("【Boss房间】火墙到位，Boss 战开始")
	_start_auto_scroll()

	AudioManager.play_sound(&"zhandou3")
	var cam = get_node("Player/Camera2D")
	cam.limit_left = 0
	cam.limit_right = 100000

	if _boss_ref and _boss_ref.has_method("start_boss_battle"):
		_boss_ref.start_boss_battle()

	_is_boss_phase = true
