
extends Area2D

class_name JIANCI

@export var damage: int = 1

## 连续伤害的间隔时间（秒）
@export var tick_interval: float = 0.3

# 记录当前正在受伤害的 HurtBox（支持多个目标同时触发）
var _active_targets: Dictionary = {}  # { HurtBox: Timer }

func _ready() -> void:
	monitoring = true
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)
	if not area_exited.is_connected(_on_area_exited):
		area_exited.connect(_on_area_exited)

func _on_area_entered(area: Area2D) -> void:
	if not area is HurtBox:
		return
	# 立刻造成第一次伤害
	area.take_damage(damage)
	
	# 为该 HurtBox 创建一个定时器，每隔 tick_interval 尝试造成伤害
	_try_start_timer(area)

func _on_area_exited(area: Area2D) -> void:
	if area in _active_targets:
		var timer = _active_targets[area]
		if is_instance_valid(timer):
			timer.queue_free()
		_active_targets.erase(area)

func _try_start_timer(area: HurtBox) -> void:
	# 如果已经存在定时器，不重复创建
	if area in _active_targets:
		return
	
	var timer = Timer.new()
	timer.wait_time = tick_interval
	timer.timeout.connect(_on_tick.bind(area))
	add_child(timer)
	timer.start()
	_active_targets[area] = timer

func _on_tick(area: HurtBox) -> void:
	# 检查目标是否仍然存在且有效
	if not is_instance_valid(area):
		_remove_timer(area)
		return
	
	# 检查目标是否仍然与自身重叠
	var overlapping = get_overlapping_areas()
	if area not in overlapping:
		_remove_timer(area)
		return
	
	# 造成一次伤害（无敌时间由 HurtBox 自己管理）
	area.take_damage(damage)

func _remove_timer(area: HurtBox) -> void:
	if area in _active_targets:
		var timer = _active_targets[area]
		if is_instance_valid(timer):
			timer.queue_free()
		_active_targets.erase(area)
