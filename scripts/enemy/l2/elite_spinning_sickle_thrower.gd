
# res://scripts/enemy/l2/elite_spinning_sickle_thrower.gd
# 精英镰刀怪：面向玩家巡逻50px，投掷不可摧毁的镰刀，HP=1时狂暴
extends BaseEnemy
class_name Elite_SpinningSickleThrower

enum EliteState { PATROL, ATTACK, RAGE_CHARGE, RAGE_THROW }

@onready var detect_range: Area2D = $DetectRange
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var mySickle = $Sickle

@export var elite_max_hp: int = 2           # 精英怪最大生命值
@export var move_speed: float = 30.0        # 移动速度
@export var contact_damage: int = 1         # 接触伤害（碰撞/近战伤害）
@export var patrol_distance: float = 50.0   # 巡逻距离
@export var attack_cooldown: float = 1      # 攻击冷却时间
@export var sickle_speed: float = 350.0     # 镰刀飞行速度
@export var rage_charge_duration: float = 1.0  # 狂暴蓄力时长
@export var rage_sickle_count: int = 4      # 狂暴镰刀数量（扇形发射数）
@export var rage_sickle_spread: float = 45.0   # 狂暴镰刀散射角度（度）
@export var rage_sickle_speed: float = 350.0   # 狂暴镰刀飞行速度

var _elite_state: int = EliteState.PATROL
var _start_position: Vector2
var _attack_timer: float = 0.0
var _rage_charge_timer: float = 0.0
var _is_raging: bool = false
var _rage_done: bool = false
var _move_dir: float = 1.0
var _is_throwing: bool = false
var _sickle_base_x: float = 0.0

const SICKLE_SCENE = preload("res://scenes/enemy/l2/Sickle.tscn")


func _ready() -> void:
	super()
	_start_position = global_position
	current_hp = elite_max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	hitbox.collision_mask = 1

	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)

	anim.animation_finished.connect(_on_anim_finished)

	_sickle_base_x = mySickle.position.x

	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)

	match _elite_state:
		EliteState.PATROL:
			_update_patrol(delta)
		EliteState.ATTACK:
			_update_attack(delta)
		EliteState.RAGE_CHARGE:
			_update_rage_charge(delta)
		EliteState.RAGE_THROW:
			_update_rage_throw(delta)

	_face_player_visual()
	move_and_slide()


func _face_player_visual() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var face_left = player.global_position.x < global_position.x
	anim.flip_h = face_left
	mySickle.position.x = _sickle_base_x * (-1.0 if face_left else 1.0)


func _update_patrol(_delta: float) -> void:
	anim.play("idle")
	mySickle.visible=true
	_check_turn()
	velocity.x = move_speed * _move_dir


func _check_turn() -> void:
	var edge_ray = floor_detect_right if _move_dir > 0 else floor_detect_left
	if not edge_ray.is_colliding() or is_on_wall():
		_move_dir *= -1.0
		return

	var distance = global_position.x - _start_position.x
	if _move_dir > 0 and distance > patrol_distance:
		_move_dir = -1.0
	elif _move_dir < 0 and distance < -patrol_distance:
		_move_dir = 1.0


func _update_attack(delta: float) -> void:
	if _is_throwing:
		velocity.x = 0.0
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		velocity.x = 0.0
		_face_player_visual()
		_throw_sickle()
		_is_throwing = true
		mySickle.visible=false
		anim.play("throw")
	else:
		_update_patrol(delta)


func _throw_sickle() -> void:
	AudioManager.play_sound(&"jianxuanzhuan")
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	var sickle = SICKLE_SCENE.instantiate()
	sickle.global_position = global_position + dir * 16.0
	get_tree().current_scene.add_child(sickle)
	if sickle.has_method("initialize"):
		sickle.initialize(dir, sickle_speed)


func _update_rage_charge(delta: float) -> void:
	velocity.x = 0.0
	_rage_charge_timer -= delta
	if _rage_charge_timer <= 0.0:
		_throw_rage_sickles()
		mySickle.visible=false
		anim.play("throw")
		_is_throwing = true
		_elite_state = EliteState.RAGE_THROW


func _throw_rage_sickles() -> void:
	AudioManager.play_sound(&"jianxuanzhuan")
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var base_dir = (player.global_position - global_position).normalized()
	var count = max(rage_sickle_count, 2)
	var spread_step = rage_sickle_spread / float(count - 1)
	var start_angle = -rage_sickle_spread * 0.5

	for i in range(count):
		var angle = start_angle + spread_step * i
		var dir = base_dir.rotated(deg_to_rad(angle))
		var sickle = SICKLE_SCENE.instantiate()
		sickle.global_position = global_position + dir * 16.0
		get_tree().current_scene.add_child(sickle)
		if sickle.has_method("initialize"):
			sickle.initialize(dir, rage_sickle_speed)


func _update_rage_throw(_delta: float) -> void:
	velocity.x = 0.0


func _check_player_in_range() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return detect_range.overlaps_body(player)


func _on_anim_finished() -> void:
	if is_dead:
		return
	if anim.animation == "throw":
		_is_throwing = false
		mySickle.modulate = Color.WHITE
		if _elite_state == EliteState.RAGE_THROW:
			_rage_done = true
			anim.modulate = Color.WHITE
			_elite_state = EliteState.PATROL
			_attack_timer = attack_cooldown
			if _check_player_in_range():
				_elite_state = EliteState.ATTACK
		else:
			_attack_timer = attack_cooldown


func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _rage_done:
		_elite_state = EliteState.ATTACK
		_attack_timer = 0.0
		return
	if _elite_state == EliteState.PATROL:
		_elite_state = EliteState.ATTACK
		_attack_timer = 0.0


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if _elite_state == EliteState.ATTACK:
		_elite_state = EliteState.PATROL


func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	if _elite_state == EliteState.RAGE_CHARGE:
		return
	current_hp -= amount
	if current_hp <= 0:
		_die()
		return
	AudioManager.play_sound(&"shoushang")
	if current_hp <= 1 and not _is_raging:
		_start_rage()



func _start_rage() -> void:
	_is_raging = true
	_elite_state = EliteState.RAGE_CHARGE
	_rage_charge_timer = rage_charge_duration
	_attack_timer = 0.0
	_is_throwing = false
	velocity = Vector2.ZERO
	mySickle.modulate = Color.RED
	anim.play("xuli")
	anim.modulate = Color.BLACK


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(&"disiwang")
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	queue_free()


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
