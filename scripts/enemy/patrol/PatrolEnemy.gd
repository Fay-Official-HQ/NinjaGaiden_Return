# res://scripts/enemy/patrol/PatrolEnemy.gd
# 地面巡逻怪：在平台上左右往返行走
class_name PatrolEnemy
extends BaseEnemy

# ── 巡逻检测射线（子类场景须包含同名节点） ──
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect: RayCast2D = $WallDetect

# 出生位置（用于 patrol_distance 范围限制）
var _start_position: Vector2


func _ready() -> void:
	super()
	_start_position = global_position


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_check_turn()
	velocity.x = data.move_speed * (1.0 if facing_right else -1.0)
	move_and_slide()
	_update_animation()


# ── 重力（继承自 CharacterBody2D，手动应用） ──
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta


# ── 转弯条件：走到边缘 / 撞墙 / 超出巡逻范围 ──
func _check_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	var patrol_data := data as PatrolEnemyData

	# 前方没地面 → 掉头
	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)
		return

	# 超出巡逻半径 → 掉头
	if patrol_data:
		var distance = global_position.x - _start_position.x
		if distance > patrol_data.patrol_distance:
			_set_facing(false)
		elif distance < -patrol_data.patrol_distance:
			_set_facing(true)


# ── 动画状态切换 ──
func _update_animation() -> void:
	if is_on_floor():
		anim.play("walk")
	else:
		anim.play("idle")
