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

# 状态节点引用
@onready var idle_state: IdleState = $StateMachine/IdleState
@onready var run_state: RunState = $StateMachine/RunState
@onready var jump_state: JumpState = $StateMachine/JumpState
@onready var fall_state: FallState = $StateMachine/FallState

# 当前 HP
var current_hp: int

# 面向方向
var facing_direction: float = 1.0

# 受伤后的短暂无敌时间
var invincible_timer: float = 0.0
const INVINCIBLE_TIME: float = 1.5

func _ready() -> void:
	current_hp = data.max_hp
	movement.initialize(self)
	animation.initialize(animated_sprite)

	# 连接受伤信号
	if hurt_box:
		hurt_box.took_damage.connect(_on_hurt_box_took_damage)

func _process(delta: float) -> void:
	input.update_input()
	input.update_buffer(delta)
	state_machine.update(delta)

	# 受伤无敌计时器
	if invincible_timer > 0:
		invincible_timer -= delta
		# 闪烁效果（可选）
		animated_sprite.modulate.a = 0.5 if fmod(invincible_timer * 10, 1.0) < 0.5 else 1.0
	else:
		animated_sprite.modulate.a = 1.0

func _physics_process(delta: float) -> void:
	movement.apply_gravity(delta)
	state_machine.physics_update(delta)
	position = position.round()

func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animation.flip_sprite(facing_direction)

func _on_hurt_box_took_damage(damage: int) -> void:
	if invincible_timer > 0:
		return
		
	current_hp -= damage
	print("玩家受伤，当前HP：", current_hp)
	
	if current_hp <= 0:
		die()
	else:
		invincible_timer = INVINCIBLE_TIME
		# 可在这里播放受伤动画，或进入受伤状态（你已有 shoushang 动画）
		# 暂时简化：播放一下受伤动画
		# animation.play("shoushang")  # 如果你有这个动画资源

func die() -> void:
	print("玩家死亡！")
	# 暂时隐藏角色，实际可做死亡动画和重生逻辑
	hide()
	# 停止处理
	set_process(false)
	set_physics_process(false)
