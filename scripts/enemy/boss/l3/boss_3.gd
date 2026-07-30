# res://scripts/enemy/boss/l3/boss_3.gd
extends CharacterBody2D
class_name Boss3

@export var data: BossData_3

## 显现技能出现的固定位置坐标（由 BossSpawner 自动传入或在关卡场景中手动设置）
@export var appear_target_pos: Vector2
## BOSS 掉落触发展现的 Y 轴阈值，超过此值自动触发 Appear
@export var fall_dead_y: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtRoot/HurtBox
@onready var state_machine: Boss3StateMachine = $BossStateMachine
@onready var boss_ui: BossUI = $BossUI
@onready var sword_hit_box: Area2D = $AttackRoot/SwordHitBox
@onready var crouch_hit_box: Area2D = $AttackRoot/CrouchHitBox
@onready var hurtbox_collision: CollisionShape2D = $HurtRoot/HurtBox/CollisionShape2D
@onready var floor_detect_left: RayCast2D = $FloorDetectLeft
@onready var floor_detect_right: RayCast2D = $FloorDetectRight
@onready var wall_detect_left: RayCast2D = $WallDetectLeft
@onready var wall_detect_right: RayCast2D = $WallDetectRight

# ── 新 AI 三层组件 ──
var eye_component: EyeComponent
var brain_component: BrainComponent
var hands_component: HandsComponent
var input_package: InputPackage

var player_ref: Player
var current_hp: int
var is_dead: bool = false
var is_invincible: bool = false
var facing_direction: float = 1.0
var is_enhanced: bool = false
var ignore_gravity: bool = false

# 撞墙冻结帧数（>0 时禁止向墙推）
var wall_stuck_frames: int = 0

# HurtBox 下蹲参数
var _normal_hurtbox_size: Vector2
var _normal_hurtbox_pos: Vector2
var _crouch_hurtbox_size: Vector2 = Vector2(17, 12)
var _crouch_hurtbox_pos: Vector2 = Vector2(-0.5, 20)

var _flash_tween: Tween
var _spawn_point: Vector2
var _special_move_trigger_count: int = 0  # 必杀技触发次数（最多3次，含首次）
const SPECIAL_MOVE_HP_THRESHOLDS: Array[int] = [22, 12]  # 第2/3次触发的血量阈值

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()

	# ── 初始化新 AI 三层组件 ──
	eye_component = EyeComponent.new()
	brain_component = BrainComponent.new()
	hands_component = HandsComponent.new()
	input_package = InputPackage.new()
	brain_component.initialize(self, input_package)
	hands_component.initialize(self, brain_component, input_package)

	# 保存受伤框碰撞体原始参数
	_normal_hurtbox_size = hurtbox_collision.shape.size
	_normal_hurtbox_pos = hurtbox_collision.position

	get_tree().create_timer(1.0).timeout.connect(func():
		AudioManager.play_sound(&"thehero")
	, CONNECT_ONE_SHOT)

	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.play("idle")
		animated_sprite.modulate.a = 0.0

	_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	# 新流程：眼睛 → 大脑 → 双手 → 状态机
	if player_ref:
		eye_component.update(self, player_ref)
		brain_component.update(delta, eye_component)
		hands_component.process(delta)
	state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var prev_x = global_position.x
	# 双手组件处理基础物理（重力 + 移动）
	hands_component.physics(delta)
	# 状态机处理动作物理（如剑术突进、飞行等）
	state_machine.physics_update(delta)
	# 统一调用 move_and_slide（状态不再各自调用）
	move_and_slide()

	# 撞墙冻结检测：如果撞墙且几乎没有移动，冻结一段时间
	if wall_stuck_frames > 0:
		wall_stuck_frames -= 1
	elif is_on_wall() and abs(global_position.x - prev_x) < 0.5:
		wall_stuck_frames = 15  # 冻结 ~0.25 秒（60fps）

	# 防止 BOSS 滑动（仅 IdleState 站定时生效，避免落地抖动）
	if not is_dead and is_on_floor() and abs(velocity.x) < 1.0:
		velocity.x = 0.0
		if state_machine.current_state is Boss3IdleState:
			global_position.x = prev_x

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is Boss3AppearState:
		return
	if state_machine.current_state is Boss3SpecialMoveState:
		return

	# 剑术备战状态下被攻击 → 自动格挡（音效+火花，不掉血）
	if state_machine.current_state is Boss3SwordReadyState:
		AudioManager.play_sound(&"fangyu")
		var ready_state = state_machine.current_state as Boss3SwordReadyState
		ready_state.spawn_block_spark()
		return

	# 格挡状态下被攻击 → 抵消伤害，播放音效和火花
	if state_machine.current_state is Boss3BlockState:
		AudioManager.play_sound(&"fangyu")
		var block_state = state_machine.current_state as Boss3BlockState
		block_state.spawn_block_spark()
		return

	# ── 必杀技触发（最多3次）：首次受伤 → HP<22 → HP<12 ──
	if _special_move_trigger_count < 3:
		var trigger = false
		if _special_move_trigger_count == 0:
			# 第一次受伤必定触发
			trigger = true
		else:
			# 检查血量阈值：本次伤害后 HP 是否低于对应的阈值
			var hp_after = current_hp - damage
			if hp_after < SPECIAL_MOVE_HP_THRESHOLDS[_special_move_trigger_count - 1]:
				trigger = true

		if trigger:
			_special_move_trigger_count += 1
			state_machine.change_state_by_name("Boss3SpecialMoveState")
			return

	# 被动格挡：Idle/Run/Crouch 状态下站立地面、面向玩家时，按血量阶段概率格挡
	var blockable_state = state_machine.current_state is Boss3IdleState \
		or state_machine.current_state is Boss3RunState \
		or state_machine.current_state is Boss3CrouchState
	if blockable_state and is_on_floor() and _is_player_in_front():
		if randf() < _get_block_chance():
			AudioManager.play_sound(&"fangyu")
			state_machine.change_state_by_name("Boss3BlockState", {"trigger_effects": true})
			return

	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	_update_enhancement_state()
	AudioManager.play_sound(&"shoushang")

	if current_hp <= 0:
		var director = get_node_or_null("BossUI/BossDeathDirector") as BossDeathDirector_3
		if director:
			director.play_death_sequence(self)
		else:
			state_machine.change_state_by_name("Boss3DeathState")
	elif is_heavy:
		state_machine.change_state_by_name("Boss3HurtState")
	else:
		_flash_white()

func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)

func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animated_sprite.flip_h = facing_direction < 0
	# 镜像翻转所有攻击框，保持攻击判定在面朝前方
	var attack_root = get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = facing_direction

## 下蹲时缩小受伤框，避免玩家站立攻击命中
func set_hurtbox_crouch(enabled: bool) -> void:
	if enabled:
		hurtbox_collision.shape.size = _crouch_hurtbox_size
		hurtbox_collision.position = _crouch_hurtbox_pos
	else:
		hurtbox_collision.shape.size = _normal_hurtbox_size
		hurtbox_collision.position = _normal_hurtbox_pos

func trigger_appear_if_alive() -> void:
	if is_dead:
		return
	if state_machine.current_state is Boss3AppearState:
		return
	state_machine.change_state_by_name("Boss3AppearState", {"target_pos": appear_target_pos})

func _tween_spawn_in() -> void:
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		state_machine.start()
	)

func die() -> void:
	is_dead = true
	is_enhanced = false
	animated_sprite.self_modulate = Color.WHITE
	set_physics_process(false)
	set_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

## 判断玩家是否在 BOSS 正面（用于被动格挡判定）
func _is_player_in_front() -> bool:
	if not player_ref:
		return false
	if facing_direction > 0:
		return player_ref.global_position.x > global_position.x
	else:
		return player_ref.global_position.x < global_position.x

## 根据当前血量返回格挡概率（分阶段提升，数据驱动）
func _get_block_chance() -> float:
	if current_hp <= data.enhanced_hp_threshold:
		return data.block_chance_enhanced
	if current_hp <= data.phase2_hp_threshold:
		return data.block_chance_phase2
	return data.block_chance_base

func _update_enhancement_state() -> void:
	var should_enhance = current_hp <= data.enhanced_hp_threshold and current_hp > 0
	if should_enhance and not is_enhanced:
		is_enhanced = true
		print("【假隼龙】进入强化状态")
	elif not should_enhance and is_enhanced:
		is_enhanced = false
		print("【假隼龙】退出强化状态")
