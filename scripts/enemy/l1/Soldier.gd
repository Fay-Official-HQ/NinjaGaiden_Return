# 士兵：地面巡逻，检测到玩家后蓄力变红 → 射激光 → 冷却 → 再蓄力
extends BaseEnemy
class_name Soldier

enum SoldierState { PATROL, CHARGE, SHOOT }

@onready var detect_range: Area2D = $DetectRange
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight

var _state: int = SoldierState.PATROL
var _start_position: Vector2
var _charge_timer: float = 0.0
var _shoot_cooldown: float = 0.0


func _ready() -> void:
	super()
	_start_position = global_position

	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_shoot_finished)

	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	match _state:
		SoldierState.PATROL:
			_update_patrol(delta)
		SoldierState.CHARGE:
			_update_charge(delta)
		SoldierState.SHOOT:
			_update_shoot(delta)

	move_and_slide()


# ==================== 巡逻 ====================

func _update_patrol(_delta: float) -> void:
	anim.play("walk")
	_check_turn()
	velocity.x = data.move_speed * (1.0 if facing_right else -1.0)


func _check_turn() -> void:
	var edge_ray = floor_detect_right if facing_right else floor_detect_left
	if not edge_ray.is_colliding() or is_on_wall():
		_set_facing(not facing_right)
		return

	var distance = global_position.x - _start_position.x
	if distance > 100.0:
		_set_facing(false)
	elif distance < -100.0:
		_set_facing(true)


# ==================== 蓄力 ====================

func _update_charge(delta: float) -> void:
	_face_player()
	velocity.x = 0.0
	anim.play("idle")

	_charge_timer -= delta
	if _charge_timer <= 0.0:
		anim.modulate = Color.WHITE  # 恢复原色
		AudioManager.play_sound((data as SoldierData).shoot_sound)
		_shoot_laser()
		_state = SoldierState.SHOOT
		_shoot_cooldown = (data as SoldierData).attack_cooldown


# ==================== 射击冷却 ====================

func _update_shoot(delta: float) -> void:
	_face_player()
	velocity.x = 0.0

	if anim.animation != "shoot":
		anim.play("idle")

	_shoot_cooldown -= delta
	if _shoot_cooldown <= 0.0:
		# 冷却结束 → 再次蓄力
		anim.modulate = Color(1.0, 0.3, 0.3)  # 变红
		_charge_timer = (data as SoldierData).charge_duration
		_state = SoldierState.CHARGE


func _shoot_laser() -> void:
	var soldier_data = data as SoldierData
	if not soldier_data:
		return

	var laser = preload("res://scenes/enemy/l1/soldier_laser.tscn").instantiate()
	var dir = 1.0 if facing_right else -1.0
	#激光位置
	laser.global_position = global_position + Vector2(14 if facing_right else -14, -3)
	get_tree().current_scene.add_child(laser)
	laser.initialize(dir, soldier_data.laser_speed)

	anim.play("shoot")


func _on_shoot_finished() -> void:
	if is_dead:
		return
	if _state == SoldierState.PATROL:
		anim.play("walk")
	else:
		anim.play("idle")


# ==================== 朝向玩家 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


# ==================== 玩家检测 ====================

func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = SoldierState.CHARGE
	_charge_timer = (data as SoldierData).charge_duration
	anim.modulate = Color(1.0, 0.3, 0.3)  # 变红


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = SoldierState.PATROL
	anim.modulate = Color.WHITE  # 恢复原色


# ==================== 重力 ====================

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
