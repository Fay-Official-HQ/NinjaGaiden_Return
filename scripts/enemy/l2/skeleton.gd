# res://scripts/enemy/l2/skeleton.gd
# 骷髅敌人：可复活的巡逻怪
# 死亡流程：death动画 → default动画（骷髅堆）→ 2秒后revive动画 → 复活继续巡逻
class_name Skeleton
extends BaseEnemy

# ── 巡逻检测射线（子类场景须包含同名节点） ──
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect: RayCast2D = $WallDetect

# ── 可编辑参数 ──
@export var skeleton_max_hp: int = 1
@export var move_speed: float = 60.0
@export var contact_damage: int = 1
@export var patrol_distance: float = 150.0
@export var revive_delay: float = 2.0

# ── 运行时状态 ──
var _start_position: Vector2
var _is_reviving: bool = false
var _revive_timer: float = 0.0
var _death_anim_played: bool = false


func _ready() -> void:
	super()
	_start_position = global_position
	current_hp = skeleton_max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	hitbox.collision_mask = 1
	hurtbox.monitorable = true


func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		_update_death_state(delta)
		return

	_apply_gravity(delta)
	_check_turn()
	velocity.x = move_speed * (1.0 if facing_right else -1.0)
	move_and_slide()
	_update_animation()


func _update_death_state(delta: float) -> void:
	if not _death_anim_played:
		return

	if _is_reviving:
		return

	if anim.animation != "default":
		anim.play("default")

	_revive_timer -= delta
	if _revive_timer <= 0.0:
		_start_revive()


func _start_revive() -> void:
	_is_reviving = true
	anim.play("revive")
	anim.animation_finished.connect(_on_revive_finished, CONNECT_ONE_SHOT)


func _on_revive_finished() -> void:
	_is_reviving = false
	is_dead = false
	_death_anim_played = false

	current_hp = skeleton_max_hp

	hitbox.monitoring = true
	hitbox.monitorable = true
	hurtbox.monitoring = true
	hurtbox.monitorable = true

	set_physics_process(true)
	_update_animation()


func _die() -> void:
	is_dead = true
	_revive_timer = revive_delay
	_is_reviving = false
	_death_anim_played = false

	velocity = Vector2.ZERO

	AudioManager.play_sound(&"disiwang")

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	_death_anim_played = true


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta


func _check_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left

	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)
		return

	var distance = global_position.x - _start_position.x
	if distance > patrol_distance:
		_set_facing(false)
	elif distance < -patrol_distance:
		_set_facing(true)


func _update_animation() -> void:
	if is_on_floor():
		anim.play("walk")
	else:
		anim.play("idle")
