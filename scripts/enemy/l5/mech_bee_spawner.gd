extends Node2D
class_name MechBeeSpawner

## ============================================================
##  MechBeeSpawner —— 机械蜂生成器
##  （参考第一关蝙蝠生成器 + 第四关鬼火生成器）
## ============================================================
##  功能：
##    - one_shot = true（默认）：玩家进入 TriggerArea 生成一波机械蜂后，生成器消失
##    - one_shot = false：玩家进入立即生成一波；持续待在区域内时，
##      每隔 spawn_interval 秒持续生成；离开暂停、再进入恢复
##    - 机械蜂在 SpawnPosition 生成，以 fall 动画直线飞向 FallTarget，再追击玩家
##    - 无生成音效（与鬼火生成器不同）
##  场景结构：
##    MechBeeSpawner (Node2D)
##    ├─ TriggerArea (Area2D)      ← 碰撞框拖成触发区域
##    ├─ SpawnPosition (Marker2D)  ← 机械蜂生成坐标（fall 起点）
##    └─ FallTarget (Marker2D)     ← 机械蜂坠落目标坐标（fall 终点）
##  使用：在关卡中右键实例 → Editable Children，拖拽 TriggerArea/标记点调整位置
## ============================================================

# ── Inspector 可调参数 ──
@export var spawn_count: int = 1            # 一次生成几只机械蜂
@export var spawn_offset_x: float = 30.0    # 机械蜂之间的横向间距（像素），生成点和坠落目标点都按此分散
@export var one_shot: bool = true           # true=触发一次后生成器消失；false=可重复触发
@export var spawn_interval: float = 2.0     # 重复触发时，玩家待在区域内每波的间隔（秒）
@export var max_spawns: int = -1            # 重复触发的总波数上限，-1=无限

var _is_stopped: bool = false
var _player_in_area: bool = false
var _spawned_waves: int = 0
var _timer: Timer = null

@onready var trigger_area: Area2D = $TriggerArea
@onready var spawn_position: Node2D = $SpawnPosition
@onready var fall_target: Node2D = $FallTarget


func _ready() -> void:
	trigger_area.body_entered.connect(_on_body_entered)
	trigger_area.body_exited.connect(_on_body_exited)


# ==================== 玩家进出区域 ====================

func _on_body_entered(body: Node2D) -> void:
	if _is_stopped:
		return
	if not body.is_in_group("player"):
		return

	if one_shot:
		# 一次性：生成一波后生成器消失（延迟到物理冲刷结束，避免信号回调中 add_child 报错）
		call_deferred("_do_spawn")
		return

	# 重复触发：立即生成一波，持续待在区域则每间隔继续生成
	_player_in_area = true
	call_deferred("_start_spawning")


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	_player_in_area = false
	_stop_timer()


# ==================== 持续生成 ====================

# 延迟执行的开始生成：此刻已不在物理查询阶段，可以安全 add_child
func _start_spawning() -> void:
	if _is_stopped or not _player_in_area:
		return
	_do_spawn()
	_start_timer()


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


# ==================== 生成 ====================

func _do_spawn() -> void:
	if _is_stopped:
		return
	if max_spawns >= 0 and _spawned_waves >= max_spawns:
		stop_spawning()
		return

	var scene = preload("res://scenes/enemy/l5/mech_bee.tscn")
	var spawn_origin = spawn_position.global_position
	var target_pos = fall_target.global_position
	for i in range(spawn_count):
		var enemy = scene.instantiate()
		# 以中心为基准横向分散（鬼火同款）：生成点和坠落目标点使用相同的偏移，
		# 保证每只机械蜂的飞行轨迹平行，不会最终重叠
		var offset_x = (i - (spawn_count - 1) / 2.0) * spawn_offset_x
		enemy.global_position = spawn_origin + Vector2(offset_x, 0)
		get_tree().current_scene.add_child(enemy)
		# 指定各自的坠落目标坐标，MechBee 进入 FALL 阶段
		enemy.start_fall(target_pos + Vector2(offset_x, 0))
	_spawned_waves += 1

	if one_shot:
		queue_free()


# ==================== 停止生成接口 ====================

# 公开接口：调用后永久停止生成（不会因玩家再次进入而恢复）。
# 用法：在某个关键怪物被杀死时调用，例如在其 _die() 里：
#   var spawner = get_tree().current_scene.get_node("enemys/MechBeeSpawner")
#   spawner.stop_spawning()
func stop_spawning() -> void:
	_is_stopped = true
	_player_in_area = false
	_stop_timer()
