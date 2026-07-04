extends BaseEnemy
class_name ChaserSoldier

const JUMP_VELOCITY_Y: float = -300.0

enum SoldierState { CHASE, CHARGE, SHOOT }

var _state: int = SoldierState.CHASE
var _charge_timer: float = 0.0
var _shoot_cooldown: float = 0.0
var _stop_distance: float = 150.0

var _charge_duration: float = 0.3
var _attack_cooldown: float = 0.5
var _chase_speed: float = 150.0
var _bullet_speed: float = 300.0
var _shoot_sound: StringName = &"shibingfashe"
var _death_sound: StringName = &"disiwang"

@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight


func _ready() -> void:
	super()
	current_hp = 1
	_face_player()
	anim.play("run")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += 980.0 * delta

	match _state:
		SoldierState.CHASE:
			_update_chase(delta)
		SoldierState.CHARGE:
			_update_charge(delta)
		SoldierState.SHOOT:
			_update_shoot(delta)

	move_and_slide()


func _update_chase(_delta: float) -> void:
	_face_player()
	anim.play("run")

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dist_x = abs(player.global_position.x - global_position.x)
	if dist_x <= _stop_distance:
		_state = SoldierState.CHARGE
		_charge_timer = _charge_duration
		anim.modulate = Color(1.0, 0.3, 0.3)
		return

	velocity.x = _chase_speed * (1.0 if facing_right else -1.0)

	if _should_jump_obstacle():
		velocity.y = JUMP_VELOCITY_Y


func _should_jump_obstacle() -> bool:
	if not is_on_floor():
		return false
	if is_on_wall():
		return true
	var floor_ray = floor_detect_right if facing_right else floor_detect_left
	floor_ray.force_raycast_update()
	if not floor_ray.is_colliding():
		return true
	return false


func _update_charge(delta: float) -> void:
	_face_player()
	velocity.x = 0.0
	anim.play("idle")

	# 玩家跑远了就回去追
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist_x = abs(player.global_position.x - global_position.x)
		if dist_x > _stop_distance * 1.5:
			_state = SoldierState.CHASE
			anim.play("run")
			return

	_charge_timer -= delta
	if _charge_timer <= 0.0:
		anim.modulate = Color.WHITE
		AudioManager.play_sound(_shoot_sound)
		_shoot_bullet()
		_state = SoldierState.SHOOT
		_shoot_cooldown = _attack_cooldown


func _update_shoot(delta: float) -> void:
	_face_player()
	velocity.x = 0.0
	if anim.animation != "shoot":
		anim.play("idle")

	# 玩家跑远了就回去追
	var player = get_tree().get_first_node_in_group("player")
	if player:
		var dist_x = abs(player.global_position.x - global_position.x)
		if dist_x > _stop_distance * 1.5:
			_state = SoldierState.CHASE
			anim.play("run")
			return

	_shoot_cooldown -= delta
	if _shoot_cooldown <= 0.0:
		_state = SoldierState.CHARGE
		_charge_timer = _charge_duration
		anim.modulate = Color(1.0, 0.3, 0.3)


func _shoot_bullet() -> void:
	var bullet_scene = preload("res://scenes/enemy/l2/soldier_bullet.tscn")
	var dir = 1.0 if facing_right else -1.0
	var origin = global_position + Vector2(14 * dir, -3)

	var bullet = bullet_scene.instantiate()
	bullet.global_position = origin
	get_tree().current_scene.add_child(bullet)
	bullet.initialize(dir, _bullet_speed)

	anim.play("shoot")


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(_death_sound)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
