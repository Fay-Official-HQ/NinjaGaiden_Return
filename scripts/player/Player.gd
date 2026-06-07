# res://scripts/player/Player.gd
extends CharacterBody2D

class_name Player

@export var data: PlayerData

# 组件解耦引用
@onready var input: InputComponent = $Components/InputComponent
@onready var movement: MovementComponent = $Components/MovementComponent
@onready var animation: AnimationComponent = $Components/AnimationComponent
@onready var state_machine: StateMachine = $StateMachine
@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtRoot/HurtBox
@onready var hurtbox_collision: CollisionShape2D = $HurtRoot/HurtBox/CollisionShape2D
@onready var ninjutsu: NinjutsuComponent = $Components/NinjutsuComponent
@onready var sword: SwordComponent = $Components/SwordComponent

# 状态节点引用
@onready var idle_state: IdleState = $StateMachine/IdleState
@onready var run_state: RunState = $StateMachine/RunState
@onready var jump_state: JumpState = $StateMachine/JumpState
@onready var fall_state: FallState = $StateMachine/FallState
@onready var hurt_state: HurtState = $StateMachine/HurtState

# 当前 HP
var current_hp: int

# 面向方向
var facing_direction: float = 1.0

# 受伤后的短暂无敌时间
var invincible_timer: float = 0.0
const INVINCIBLE_TIME: float = 1.5
var _was_invincible: bool = false

# 必杀技无敌状态（由 DragonFlashState 控制）
var is_invincible: bool = false
# 必杀技重力禁用（由 DragonFlashState 控制）
var is_gravity_disabled: bool = false

# HurtBox 原始参数（用于下蹲切换恢复）
var _normal_hurtbox_size: Vector2
var _normal_hurtbox_pos: Vector2
var _crouch_hurtbox_size: Vector2 = Vector2(13, 16)
# HurtBox 下蹲参数（默认15，越大下蹲越厉害）
var _crouch_hurtbox_pos: Vector2 = Vector2(-1.5, 10.0)

func _ready() -> void:
	current_hp = data.max_hp
	movement.initialize(self)
	animation.initialize(animated_sprite)

	# 保存 HurtBox 碰撞体原始参数
	_normal_hurtbox_size = hurtbox_collision.shape.size
	_normal_hurtbox_pos = hurtbox_collision.position

	# 连接受伤信号
	if hurt_box:
		hurt_box.took_damage.connect(_on_hurt_box_took_damage)
	#强制关闭所有攻击框
	for node in $AttackRoot.get_children():
		if node is Area2D:
			node.monitoring = false
			
			
func _process(delta: float) -> void:
	input.update_input()
	input.update_buffer(delta)
	state_machine.update(delta)

	if invincible_timer > 0:
		invincible_timer -= delta
		_was_invincible = true
		animated_sprite.modulate.a = 0.5 if fmod(invincible_timer * 10, 1.0) < 0.5 else 1.0
	else:
		if not is_gravity_disabled:
			animated_sprite.modulate.a = 1.0
		if _was_invincible:
			_was_invincible = false
			_check_overlapping_enemy_after_invincibility()

func _physics_process(delta: float) -> void:
	if not is_gravity_disabled:
		movement.apply_gravity(delta)
	state_machine.physics_update(delta)
	position = position.round()

func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animation.flip_sprite(facing_direction)

func _on_hurt_box_took_damage(damage: int) -> void:
	if invincible_timer > 0 or is_invincible:
		return

	current_hp -= damage
	print("玩家受伤，当前HP：", current_hp)

	if current_hp <= 0:
		die()
	else:
		invincible_timer = INVINCIBLE_TIME
		state_machine.change_state(hurt_state)

func set_hurtbox_crouch(enabled: bool) -> void:
	if enabled:
		hurtbox_collision.shape.size = _crouch_hurtbox_size
		hurtbox_collision.position = _crouch_hurtbox_pos
	else:
		hurtbox_collision.shape.size = _normal_hurtbox_size
		hurtbox_collision.position = _normal_hurtbox_pos

func _check_overlapping_enemy_after_invincibility() -> void:
	var space_state: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = hurtbox_collision.shape
	query.transform = Transform2D(0, hurtbox_collision.global_position)
	query.collision_mask = 0b100000  # 第6层 EnemyAttack
	query.collide_with_areas = true
	query.collide_with_bodies = false

	var results = space_state.intersect_shape(query)
	for hit in results:
		var area = hit.collider
		if area is EnemyHitBox:
			_on_hurt_box_took_damage(area.damage)
			return

func die() -> void:
	print("玩家死亡！")
	hide()
	set_process(false)
	set_physics_process(false)
