extends Area2D
class_name BossGroundWave

signal hit_player

const SPEED: float = 220.0
const MAX_LIFETIME: float = 8.0
const RAY_UP_OFFSET: float = 25.0
const RAY_DOWN_LENGTH: float = 60.0
const EDGE_CHECK_DIST: float = 16.0
const EDGE_RAY_DOWN: float = 50.0

var direction: float = 1.0
var _life: float = 0.0

func initialize(dir: float, spawn_pos: Vector2) -> void:
	direction = dir
	global_position = spawn_pos

func _ready() -> void:
	var hitbox = $EnemyHitBox
	if hitbox:
		hitbox.area_entered.connect(_on_hitbox_hit_player)

func _on_hitbox_hit_player(area: Area2D) -> void:
	if area is HurtBox and not area.is_boss:
		hit_player.emit()

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= MAX_LIFETIME:
		queue_free()
		return
	var ground_y = _get_ground_y()
	if ground_y == INF:
		queue_free()
		return
	if not _has_ground_ahead():
		queue_free()
		return
	global_position.x += direction * SPEED * delta
	global_position.y = ground_y

func _has_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(direction * EDGE_CHECK_DIST, -RAY_UP_OFFSET)
	var to = from + Vector2(0, EDGE_RAY_DOWN)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	return not result.is_empty()

func _get_ground_y() -> float:
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(0, -RAY_UP_OFFSET)
	var to = from + Vector2(0, RAY_DOWN_LENGTH)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	if not result.is_empty():
		return result.position.y
	return INF
