# 所有数据硬编码在代码中，不需要绑定 data 资源
extends BaseEnemy
class_name RedCapParatrooper

## ============================================================
##  空降红帽兵 —— RedCapSoldier 的空降版
##  1. FALLING：生成时处于 fall 状态，播放 fall 动画，
##     伞兵被手动摆放在空中，以恒定速度缓慢飘落（descend_speed 可调），
##     并水平滑向生成器指定的降落位置（TargetPosition.x）
##     —— 空中禁用 FloorDetectFront / WallDetectFront 射线
##  2. 落地后 → 进入 CHASE / JUMP_ATTACK，逻辑与 RedCapSoldier 完全一致
## ============================================================

const CHASE_SPEED: float = 150.0
const JUMP_FORCE: float = -250.0
const JUMP_DISTANCE: float = 100.0
const JUMP_STUN: float = 0.3
const DEATH_SOUND: StringName = &"disiwang"
## 落地后地面状态的重力加速度（像素/秒²，与 RedCapSoldier 一致）
const GROUND_GRAVITY: float = 980.0

enum State { FALLING, CHASE, JUMP_ATTACK }

# ── 空降参数（Inspector 可调） ──
## 飘落速度（像素/秒，越小飘得越慢）
@export var descend_speed: float = 80.0
## 水平滑向降落点的速度（像素/秒）
@export var descend_h_speed: float = 100.0

## 由生成器设置：降落位置 X 坐标（世界坐标）
var target_landing_x: float = 0.0

var _state: int = State.FALLING
var _jump_stun: float = 0.0
var _jump_count: int = 0

@onready var floor_detect_front: RayCast2D = $FloorDetectFront
@onready var wall_detect_front: RayCast2D = $WallDetectFront
## 降落伞 Sprite2D：空中显示，落地后隐藏
@onready var parachute: Sprite2D = $Sprite2D


func _ready() -> void:
	super()
	current_hp = 1
	# 空中禁用地面/墙体检测射线（只有落地后的地面逻辑才需要）
	floor_detect_front.enabled = false
	wall_detect_front.enabled = false
	# 空中显示降落伞
	parachute.visible = true
	anim.play("fall")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_jump_stun -= delta

	match _state:
		State.FALLING:
			_falling_update(delta)
		State.CHASE:
			_apply_ground_gravity(delta)
			_face_player()
			_chase_update()
		State.JUMP_ATTACK:
			_apply_ground_gravity(delta)
			_jump_attack_update()

	move_and_slide()

	# 飘落中：位置取整到整像素，避免缓慢下落的亚像素抖动（落地后停止，避免与地面碰撞抖动）
	if _state == State.FALLING and not is_on_floor():
		global_position = global_position.round()

	if _state == State.JUMP_ATTACK and not is_on_floor() and is_on_wall() and velocity.y >= 0 and _jump_count < 6:
		_jump_count += 1
		velocity.y = JUMP_FORCE
		velocity.x = CHASE_SPEED * 1.5 * (1.0 if facing_right else -1.0)


## FALLING：以恒定速度缓慢飘落，并水平滑向降落点，落地后切换为 CHASE
func _falling_update(_delta: float) -> void:
	# 持续面朝玩家
	_face_player()

	# 缓慢飘落：恒定下落速度（不加速）
	velocity.y = descend_speed

	# 持续水平移向降落点
	var dx = target_landing_x - global_position.x
	if abs(dx) > 10.0:
		velocity.x = signf(dx) * descend_h_speed
	else:
		velocity.x = 0.0

	# 落地 → 恢复地面逻辑，收起降落伞
	if is_on_floor():
		velocity = Vector2.ZERO
		floor_detect_front.enabled = true
		wall_detect_front.enabled = true
		parachute.visible = false
		_state = State.CHASE
		_face_player()
		anim.play("walk")


## 地面状态的重力（与 RedCapSoldier 一致）
func _apply_ground_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GROUND_GRAVITY * delta


func _chase_update() -> void:
	velocity.x = CHASE_SPEED * (1.0 if facing_right else -1.0)
	anim.play("walk")

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if not is_on_floor():
		return
	if _jump_stun > 0.0:
		return

	var dist_x = abs(player.global_position.x - global_position.x)
	if dist_x <= JUMP_DISTANCE:
		_jump_count = 1
		_do_jump_attack()
		return

	if is_on_wall():
		_jump_count = 1
		_do_jump_attack()


func _jump_attack_update() -> void:
	anim.play("jump")
	velocity.x = CHASE_SPEED * 1.5 * (1.0 if facing_right else -1.0)
	if is_on_floor():
		_jump_count = 0
		_face_player()
		# 落地后如果玩家仍在 100px 内 → 立即再跳，无延迟
		var player = get_tree().get_first_node_in_group("player")
		if player:
			var dist_x = abs(player.global_position.x - global_position.x)
			if dist_x <= JUMP_DISTANCE:
				_jump_count = 1
				_do_jump_attack()
				return
		_state = State.CHASE
		_jump_stun = JUMP_STUN
		anim.play("walk")


func _do_jump_attack() -> void:
	if not is_on_floor():
		return  # 空中不允许发动攻击：只有落地后才能攻击
	_state = State.JUMP_ATTACK
	velocity.y = JUMP_FORCE
	velocity.x = CHASE_SPEED * 1.5 * (1.0 if facing_right else -1.0)
	anim.play("jump")


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)
