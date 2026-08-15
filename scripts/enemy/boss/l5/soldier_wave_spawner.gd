extends Node
class_name SoldierWaveSpawner

## 第3次轰炸的士兵波次生成器（独立挂场景节点，不随 Boss 状态切换销毁）：
## 每波：
##   1. 空中在 hongzha 节点两坐标框定范围内随机生成 1~paratrooper_max 个空降兵
##      （垂直飘落+滑向降落点，z_index=10 防地图遮挡）
##   2. 地面在 shibing 节点 2 个 Marker 处随机生成 1~2 个 AK 士兵
##      （类型在 chaser_AKsoldier / chaser_AKsoldier2 中随机）
## 本波全部消失后等待 wave_gap 秒，再生成下一波，直到 Boss 死亡。
## 所有士兵挂在关卡 enemys 节点下（与 Boss/其他敌人层级一致）。

const PARATROOPER_SCENE: PackedScene = preload("res://scenes/enemy/l5/red_cap_paratrooper.tscn")
const AK_SOLDIER_SCENE: PackedScene = preload("res://scenes/enemy/l5/chaser_AKsoldier.tscn")
const AK_SOLDIER2_SCENE: PackedScene = preload("res://scenes/enemy/l5/chaser_AKsoldier2.tscn")

## Boss 引用（Boss 死亡后停止生成并销毁本生成器）
var boss: Node = null
## 每波空降兵随机数量上限（每波实际 1~N 个，可调试）
var paratrooper_max: int = 3
## 一波士兵全部消失后，等待该秒数再生成下一波（可调试）
var wave_gap: float = 2.0

## 当前波次已生成的士兵（仅用于判断本波是否全部消失）
var _wave: Array[Node] = []
var _spawned: bool = false
## 波间等待倒计时状态：本波已全灭、正在等待 wave_gap
var _waiting: bool = false
var _gap_timer: float = 0.0


func _ready() -> void:
	_spawn_wave()


func _process(delta: float) -> void:
	# Boss 死亡 → 停止生成新波次并销毁生成器
	if boss == null or boss.is_dead:
		queue_free()
		return

	# 过滤掉已销毁（死亡动画播完 queue_free）的士兵
	var alive: Array[Node] = []
	for soldier in _wave:
		if is_instance_valid(soldier) and not soldier.is_queued_for_deletion():
			alive.append(soldier)
	_wave = alive

	# 本波全部消失 → 先等待 wave_gap 秒，再生成下一波
	if _spawned and _wave.is_empty():
		if not _waiting:
			_waiting = true
			_gap_timer = wave_gap
		_gap_timer -= delta
		if _gap_timer <= 0.0:
			_waiting = false
			_spawn_wave()


## 生成一波士兵：1~N 个空降兵 + 1~2 个随机类型 AK 追兵
func _spawn_wave() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	# 统一挂在关卡 enemys 节点下（与 Boss/其他敌人一致），找不到则挂场景根
	var enemy_parent: Node = root.get_node_or_null("enemys")
	if enemy_parent == null:
		enemy_parent = root
	_wave.clear()
	_spawn_paratroopers(enemy_parent)
	_spawn_ak_soldiers(enemy_parent)
	_spawned = true
	print("【BossAI_5】士兵波次生成：本波共 %d 个士兵" % _wave.size())


## 空降兵：在 hongzha 两坐标框定的矩形内随机生成（x/y 均随机，与导弹产生一致），
## 数量随机 1~paratrooper_max；随机指定降落点 X；z_index=10 防止被地图/前景遮挡
func _spawn_paratroopers(enemy_parent: Node) -> void:
	var hongzha := get_tree().current_scene.get_node_or_null("hongzha")
	if not hongzha:
		return
	var m1 := hongzha.get_node_or_null("Marker2D1") as Node2D
	var m2 := hongzha.get_node_or_null("Marker2D2") as Node2D
	if not m1 or not m2:
		return
	var min_x := minf(m1.global_position.x, m2.global_position.x)
	var max_x := maxf(m1.global_position.x, m2.global_position.x)
	var min_y := minf(m1.global_position.y, m2.global_position.y)
	var max_y := maxf(m1.global_position.y, m2.global_position.y)
	var count := randi_range(1, maxi(1, paratrooper_max))
	for i in count:
		var paratrooper := PARATROOPER_SCENE.instantiate()
		paratrooper.z_index = 10
		paratrooper.z_as_relative = false
		enemy_parent.add_child(paratrooper)
		paratrooper.global_position = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))
		# 降落点取生成位置正下方 → 空降兵只垂直降落，不水平滑行
		paratrooper.target_landing_x = paratrooper.global_position.x
		_wave.append(paratrooper)


## AK 追兵：从 shibing 节点 2 个 Marker 中随机取 1~2 个位置生成，
## 类型在 chaser_AKsoldier / chaser_AKsoldier2 中随机
func _spawn_ak_soldiers(enemy_parent: Node) -> void:
	var shibing := get_tree().current_scene.get_node_or_null("shibing")
	if not shibing:
		return
	var markers: Array[Node2D] = []
	for child in shibing.get_children():
		if child is Marker2D:
			markers.append(child)
	if markers.is_empty():
		return
	var count := randi_range(1, mini(2, markers.size()))
	for i in count:
		var marker: Node2D = markers.pick_random()
		var scene: PackedScene = AK_SOLDIER_SCENE if randi() % 2 == 0 else AK_SOLDIER2_SCENE
		var soldier := scene.instantiate()
		enemy_parent.add_child(soldier)
		soldier.global_position = marker.global_position
		_wave.append(soldier)
