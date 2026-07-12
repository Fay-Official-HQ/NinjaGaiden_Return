extends BaseEnemy
class_name Elite_Mars

enum EliteState { PATROL, CHASE, ATTACK, LEAP }

@onready var detect_range: Area2D = $DetectRange
@onready var hand_flame: AnimatedSprite2D = $HandSpinningFlame

## 精英怪血量
@export var elite_max_hp: int = 3
## 巡逻速度
@export var patrol_speed: float = 20.0
## 追击速度
@export var chase_speed: float = 100.0
## 停止追击并投掷的距离
@export var attack_distance: float = 100.0
## 火焰投掷物速度
@export var flame_speed: float = 500.0
## 攻击冷却时间
@export var attack_cooldown: float = 2.0
## 碰撞伤害
@export var contact_damage: int = 1

var _elite_state: int = EliteState.PATROL
var _start_position: Vector2
var _move_dir: float = 1.0
var _attack_timer: float = 0.0
var _is_throwing: bool = false
var _hand_flame_base_x: float = 0.0
var _flash_tween: Tween
var _leap_dir: float = 1.0
var _leap_has_thrown: bool = false
var _is_reviving: bool = false
var _revive_timer: float = 0.0
var _death_anim_played: bool = false

## 飞跃追击速度
@export var leap_speed: float = 350.0
## 飞跃跳跃力度
@export var leap_jump_force: float = -450.0
## 复活前摇时间
@export var revive_delay: float = 3.0

const FLAME_SCENE = preload("res://scenes/enemy/l2/SpinningFlame.tscn")


func _ready() -> void:
	super()
	_start_position = global_position
	current_hp = elite_max_hp

	var enemy_hitbox = hitbox as EnemyHitBox
	if enemy_hitbox:
		enemy_hitbox.damage = contact_damage

	hitbox.collision_mask = 1
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_anim_finished)
	_hand_flame_base_x = hand_flame.position.x
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		_apply_gravity(delta)
		move_and_slide()
		_update_death_state(delta)
		return

	_apply_gravity(delta)

	match _elite_state:
		EliteState.PATROL:
			_update_patrol(delta)
			if _check_player_in_range():
				_elite_state = EliteState.CHASE
		EliteState.CHASE:
			_update_chase(delta)
		EliteState.ATTACK:
			_update_attack(delta)
		EliteState.LEAP:
			_update_leap(delta)

	move_and_slide()


func _set_patrol_facing() -> void:
	_set_facing(_move_dir > 0)
	hand_flame.position.x = _hand_flame_base_x if _move_dir > 0 else -_hand_flame_base_x


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var is_facing_right = player.global_position.x > global_position.x
	_set_facing(is_facing_right)
	hand_flame.position.x = _hand_flame_base_x if is_facing_right else -_hand_flame_base_x


func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D


# ==================== PATROL ====================

func _update_patrol(_delta: float) -> void:
	anim.play("walk")
	_set_patrol_facing()
	_check_turn()
	velocity.x = patrol_speed * _move_dir


func _check_turn() -> void:
	var distance = global_position.x - _start_position.x
	if _move_dir > 0 and distance > 50.0:
		_move_dir = -1.0
	elif _move_dir < 0 and distance < -50.0:
		_move_dir = 1.0


# ==================== CHASE ====================

func _update_chase(_delta: float) -> void:
	_face_player()
	anim.play("walk")

	var player = _get_player()
	if not player:
		return

	var dx = player.global_position.x - global_position.x
	var dist = abs(dx)

	if dist <= attack_distance:
		_elite_state = EliteState.ATTACK
		_attack_timer = 0.0
		return

	velocity.x = chase_speed * (1.0 if dx > 0 else -1.0)


# ==================== ATTACK ====================

func _update_attack(delta: float) -> void:
	_face_player()
	velocity.x = 0.0

	if _is_throwing:
		return

	_attack_timer -= delta
	if _attack_timer <= 0.0:
		_is_throwing = true
		hand_flame.visible = false
		anim.play("throw")
		_throw_flames()
	else:
		anim.play("default")


func _throw_flames() -> void:
	AudioManager.play_sound(&"jianqianchong")
	var player = _get_player()
	if not player:
		_is_throwing = false
		_elite_state = EliteState.PATROL
		return

	var base_dir = (player.global_position - global_position).normalized()
	var base_y = global_position.y - 8.0
	var spread_angles = [-0.25, 0.0, 0.25]
	var init_vys = [-60.0, 0.0, 60.0]

	for i in range(3):
		var flame = FLAME_SCENE.instantiate()
		flame.global_position = Vector2(global_position.x, base_y)
		get_tree().current_scene.add_child(flame)
		if flame.has_method("initialize"):
			var dir = base_dir.rotated(spread_angles[i])
			var upward_strength = 200.0 + i * 300.0
			flame.initialize(dir, flame_speed, upward_strength, init_vys[i])


func _on_anim_finished() -> void:
	if is_dead:
		return
	if anim.animation == "throw":
		_is_throwing = false
		hand_flame.visible = true
		if _elite_state != EliteState.LEAP:
			_attack_timer = attack_cooldown
		anim.play("default")


# ==================== 工具方法 ====================

func _is_player_in_front() -> bool:
	var player = _get_player()
	if not player:
		return false
	if facing_right:
		return player.global_position.x > global_position.x
	else:
		return player.global_position.x < global_position.x


func _check_player_in_range() -> bool:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return detect_range.overlaps_body(player)


# ==================== 玩家检测 ====================

func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	if is_dead or _is_reviving:
		return
	if _elite_state == EliteState.CHASE or _elite_state == EliteState.ATTACK:
		_start_leap()


# ==================== LEAP ====================

func _start_leap() -> void:
	_elite_state = EliteState.LEAP
	_face_player()
	_leap_dir = 1.0 if facing_right else -1.0
	_leap_has_thrown = false
	hand_flame.visible = true
	velocity = Vector2(_leap_dir * leap_speed, leap_jump_force)
	anim.play("default")


func _update_leap(_delta: float) -> void:
	if is_on_floor():
		_elite_state = EliteState.CHASE
		_is_throwing = false
		hand_flame.visible = true
		anim.play("walk")
		return

	velocity.x = _leap_dir * leap_speed

	if not _leap_has_thrown and velocity.y >= -20.0:
		_leap_has_thrown = true
		_is_throwing = true
		hand_flame.visible = false
		anim.play("throw")
		_air_throw_flames()


func _air_throw_flames() -> void:
	var player = _get_player()
	if not player:
		return

	AudioManager.play_sound(&"jianqianchong")

	var base_dir = (player.global_position - global_position).normalized()
	var base_y = global_position.y
	var spread_angles = [-0.2, 0.0, 0.2]
	var init_vys = [-30.0, 0.0, 30.0]

	for i in range(3):
		var flame = FLAME_SCENE.instantiate()
		flame.global_position = Vector2(global_position.x, base_y)
		get_tree().current_scene.add_child(flame)
		if flame.has_method("initialize"):
			var dir = base_dir.rotated(spread_angles[i])
			var upward_strength = 100.0 + i * 200.0
			flame.initialize(dir, flame_speed * 0.8, upward_strength, init_vys[i])


# ==================== 受击/死亡 ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if is_dead or _is_reviving:
		return

	if _elite_state != EliteState.LEAP and not _is_throwing and _is_player_in_front():
		AudioManager.play_sound(&"fangyu")
		return

	current_hp -= amount
	if current_hp <= 0:
		_die()
		return
	AudioManager.play_sound(&"shoushang")
	_flash_white()


func _die() -> void:
	is_dead = true
	_death_anim_played = false
	_is_reviving = false
	_revive_timer = revive_delay
	_is_throwing = false
	_attack_timer = 0.0

	velocity = Vector2.ZERO
	hand_flame.visible = false

	AudioManager.play_sound(&"disiwang")

	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)

	anim.play("dead")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _on_death_anim_finished() -> void:
	if is_dead and not _death_anim_played:
		_death_anim_played = true


func _update_death_state(delta: float) -> void:
	if not _death_anim_played:
		return
	if _is_reviving:
		return

	if anim.animation != "reviving":
		anim.modulate = Color.BLACK
		anim.play("reviving")

	_revive_timer -= delta
	if _revive_timer <= 0.0:
		_start_get_up()


func _start_get_up() -> void:
	_is_reviving = true
	anim.modulate = Color.WHITE
	anim.play("getup")
	anim.animation_finished.connect(_on_get_up_finished, CONNECT_ONE_SHOT)


func _on_get_up_finished() -> void:
	_is_reviving = false
	is_dead = false
	_death_anim_played = false

	current_hp = elite_max_hp

	_elite_state = EliteState.CHASE
	hand_flame.visible = true
	_face_player()

	hitbox.set_deferred("monitoring", true)
	hitbox.set_deferred("monitorable", true)
	hurtbox.set_deferred("monitoring", true)
	hurtbox.set_deferred("monitorable", true)

	anim.play("walk")


func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(anim, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(anim, "modulate", Color.WHITE, 0.15)


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
