# HopperMonsterSpawner（第四关敌人生成器）
#
# 行为：
#   - 玩家进入触发区域后立即生成一波，之后只要玩家持续待在区域内，
#     每隔 spawn_interval 秒就持续生成一波；
#   - 玩家离开区域 → 暂停生成；玩家再次进入 → 恢复生成；
#   - 外部可通过 stop_spawning() 接口永久停止生成
#     （例如：某个关键怪物被杀死时调用它来停止刷怪）。
extends Node2D

@export var spawn_count: int = 1          # 每一波生成的数量
@export var spawn_offset_x: float = 30.0  # 同波次敌人之间的横向间距
@export var spawn_offset_y: float = 0.0   # 生成点垂直偏移
@export var spawn_interval: float = 2.0   # 玩家在区域内时，每波之间的间隔（秒）
@export var max_spawns: int = -1          # 最多生成波数，-1 表示无限

var _is_stopped: bool = false
var _player_in_area: bool = false
var _spawned_waves: int = 0
var _timer: Timer = null

@onready var trigger_area: Area2D = $TriggerArea
@onready var spawn_position: Node2D = $SpawnPosition


func _ready() -> void:
	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)


# ==================== 玩家进出区域 ====================

func _on_body_entered(body: Node2D) -> void:
	if _is_stopped:
		return
	if not body.is_in_group("player"):
		return
	_player_in_area = true
	# 延迟到物理冲刷结束后再生成，避免在信号回调中 add_child 修改碰撞状态报错
	call_deferred("_start_spawning")


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_area = false
	_stop_timer()


# 延迟执行的开始生成：此刻已不在物理查询阶段，可以安全 add_child
func _start_spawning() -> void:
	if _is_stopped or not _player_in_area:
		return
	_do_spawn()
	_start_timer()


# ==================== 持续生成 ====================

func _start_timer() -> void:
	if _timer == null:
		_timer = Timer.new()
		_timer.one_shot = true
		_timer.wait_time = spawn_interval
		_timer.timeout.connect(_on_timer_timeout)
		add_child(_timer)
	_timer.start()


func _stop_timer() -> void:
	if _timer:
		_timer.stop()


func _on_timer_timeout() -> void:
	if _is_stopped or not _player_in_area:
		return
	_do_spawn()
	_timer.start()


func _do_spawn() -> void:
	if _is_stopped:
		return
	if max_spawns >= 0 and _spawned_waves >= max_spawns:
		stop_spawning()
		return
	var scene = preload("res://scenes/enemy/l4/hopper_monster.tscn")
	var spawn_origin = spawn_position.global_position
	for i in range(spawn_count):
		var enemy = scene.instantiate()
		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = spawn_origin + Vector2(offset_x, spawn_offset_y)
		get_tree().current_scene.add_child(enemy)
	_spawned_waves += 1


# ==================== 停止生成接口 ====================

# 公开接口：调用后永久停止生成（不会因玩家再次进入而恢复）。
# 用法：在某个关键怪物被杀死时调用，例如在其 _die() 里：
#   var spawner = get_tree().current_scene.get_node("enemys/HopperMonsterSpawner")
#   spawner.stop_spawning()
func stop_spawning() -> void:
	_is_stopped = true
	_player_in_area = false
	_stop_timer()
