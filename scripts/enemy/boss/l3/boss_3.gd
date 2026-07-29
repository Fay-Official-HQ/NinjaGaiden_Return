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
@onready var ai_component: BossAIComponent3 = $Components/BossAIComponent
@onready var sword_hit_box: Area2D = $AttackRoot/SwordHitBox
@onready var crouch_hit_box: Area2D = $AttackRoot/CrouchHitBox
@onready var hurtbox_collision: CollisionShape2D = $HurtRoot/HurtBox/CollisionShape2D

var player_ref: Player
var current_hp: int
var is_dead: bool = false
var is_invincible: bool = false
var facing_direction: float = 1.0
var is_enhanced: bool = false
var ignore_gravity: bool = false

# HurtBox 下蹲参数
var _normal_hurtbox_size: Vector2
var _normal_hurtbox_pos: Vector2
var _crouch_hurtbox_size: Vector2 = Vector2(17, 12)
var _crouch_hurtbox_pos: Vector2 = Vector2(-0.5, 20)

var _flash_tween: Tween
var _spawn_point: Vector2

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	ai_component.initialize(self)

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
		animated_sprite.play("jump")
		animated_sprite.modulate.a = 0.0

	_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	var prev_x = global_position.x
	state_machine.physics_update(delta)
	if not is_dead and abs(velocity.x) < 1.0:
		global_position.x = prev_x

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is Boss3AppearState:
		return

	# 剑术备战状态下被攻击 → 自动格挡（音效+火花，不掉血）
	if state_machine.current_state is Boss3SwordReadyState:
		AudioManager.play_sound(&"fangyu")
		var ready_state = state_machine.current_state as Boss3SwordReadyState
		ready_state.spawn_block_spark()
		return

	# 格挡判定：仅在 Idle 状态下、站立地面、面向玩家
	if state_machine.current_state is Boss3IdleState and is_on_floor() and _is_player_in_front():
		if randf() < _get_block_chance():
			AudioManager.play_sound(&"fangyu")
			state_machine.change_state_by_name("Boss3BlockState")
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

func _is_player_in_front() -> bool:
	if not player_ref:
		return false
	if facing_direction > 0:
		return player_ref.global_position.x > global_position.x
	else:
		return player_ref.global_position.x < global_position.x

func _update_enhancement_state() -> void:
	var should_enhance = current_hp <= data.enhanced_hp_threshold and current_hp > 0
	if should_enhance and not is_enhanced:
		is_enhanced = true
		print("【假隼龙】进入强化状态")
	elif not should_enhance and is_enhanced:
		is_enhanced = false
		print("【假隼龙】退出强化状态")

## 根据当前血量返回格挡概率（参考第一关 BOSS 分阶段提升）
func _get_block_chance() -> float:
	if current_hp <= data.enhanced_hp_threshold:
		return data.block_chance_enhanced
	if current_hp <= data.phase2_hp_threshold:
		return data.block_chance_phase2
	return data.block_chance_base
