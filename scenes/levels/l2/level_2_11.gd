extends Node2D

const CHUNK_WIDTH := 480
const PRELOAD_COUNT := 2

var _chunk_scenes: Array[PackedScene] = []
var _active_chunks: Array[Node] = []


func _ready() -> void:
	SceneTransition.clear_overlay_safe()
	AudioManager.play_sound(&"bgm2_2")

	var cam = $Player/Camera2D
	cam.set_follow_x(true)
	cam.set_follow_y(false)
	cam.set_bounds(0, -1, -1, -1)
	cam.offset.y = 135
	#特别提醒：动态关卡的节点一定不要嵌套，都放在根节点下面
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_01.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_02.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_03.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_04.tscn"))
	_chunk_scenes.append(preload("res://scenes/levels/l2/chunks/Chunk_05.tscn"))
	
	
	for i in range(1, PRELOAD_COUNT + 1):
		_spawn_chunk(i * CHUNK_WIDTH)

	$Player.global_position.x = 80


func _process(_delta: float) -> void:
	var cam = $Player/Camera2D
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
