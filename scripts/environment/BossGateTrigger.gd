extends Area2D
class_name BossGateTrigger

## Wall 节点名（自动查找其下的所有 CollisionShape2D）
@export var wall_node_name: String = "Wall"

## 玩家离开后是否重新开门
@export var revert_on_exit: bool = false

## 玩家离开后多少秒重新开门（0=立即，仅 revert_on_exit 为 true 时生效）
@export var revert_delay: float = 0.0

var _shapes: Array[CollisionShape2D] = []
var _has_closed: bool = false
var _revert_timer: float = 0.0
var _timer_active: bool = false


func _ready() -> void:
	# 检测玩家的碰撞层
	collision_mask = 1
	body_entered.connect(_on_body_entered)
	if revert_on_exit:
		body_exited.connect(_on_body_exited)

	# 自动配置 Wall 的碰撞层级，使其能与玩家碰撞
	var wall = get_node_or_null(wall_node_name)
	if wall:
		wall.collision_layer = 4   # Platform 层（玩家检测此层）
		wall.collision_mask = 1    # Player 层
		for child in wall.find_children("*", "CollisionShape2D"):
			var shape := child as CollisionShape2D
			shape.disabled = true
			_shapes.append(shape)
	else:
		print("BossGateTrigger: 找不到 Wall 节点（", wall_node_name, "）")


func _process(delta: float) -> void:
	if _timer_active:
		_revert_timer -= delta
		if _revert_timer <= 0.0:
			_timer_active = false
			_set_shapes(true)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player") or _has_closed:
		return
	_has_closed = true
	print("BossGateTrigger: 玩家进入，关闭 %d 个碰撞形状" % _shapes.size())
	_set_shapes(false)


func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group("player") or not _has_closed:
		return
	if revert_delay > 0.0:
		_revert_timer = revert_delay
		_timer_active = true
	else:
		_set_shapes(true)


func _set_shapes(disabled: bool) -> void:
	for shape in _shapes:
		shape.set_deferred("disabled", disabled)
	if disabled:
		_has_closed = false
