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
@onready var charge_mist: Node2D = $Visual/ChargeMist
@onready var block_detector: Area2D = $BlockDetector
@onready var block_spark_pos: Marker2D = $Visual/BlockSparkPos

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
var _is_dead: bool = false

# 必杀技无敌状态（由 DragonFlashState 控制）
var is_invincible: bool = false
# 必杀技重力禁用（由 DragonFlashState 控制）
var is_gravity_disabled: bool = false
# 当前所在的单面攀爬墙检测区（由 ClimbableWall 设置）
var current_climbable_wall: ClimbableWall = null

# ── 灭杀系统字段 ──
var exterminate_stacks: int = 0
var exterminate_remaining_chains: int = 0
var exterminate_chain_active: bool = false
var exterminate_chain_timer: float = 0.0


# ── 灭杀蓄力跟踪（独立于 J 键攻击，完全使用 H 键）──
var _charge_hold_time: float = -1.0
var _charge_energy_timer: float = 0.0
var _charge_visual_active: bool = false
var _charge_sfx_player: AudioStreamPlayer = null
var _charge_mist_timer: float = 0.0

var _shaqi_texture = preload("res://assets/sprites/Ryu/lizitexiao/shaqi.png")
var _spark_texture = preload("res://assets/shaders/huohua.png")

# HurtBox 原始参数（用于下蹲切换恢复）
var _normal_hurtbox_size: Vector2
var _normal_hurtbox_pos: Vector2
var _crouch_hurtbox_size: Vector2 = Vector2(13, 16)
# HurtBox 下蹲参数（默认15，越大下蹲越厉害）
var _crouch_hurtbox_pos: Vector2 = Vector2(-1.5, 10.0)

func _ready() -> void:
	current_hp = data.initial_hp
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

	# 从全局状态管理器恢复 HP/MP/TP（跨小关卡持久化）
	PlayerStateManager.apply(self)

	# 格挡检测器
	block_detector.area_entered.connect(_on_block_detector_entered)


func _process(delta: float) -> void:
	input.update_input()
	input.update_buffer(delta)
	_update_charge(delta)
	_update_exterminate_chain(delta)
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

	# 控制格挡检测 — 地面站立且剑术姿势时才启用
	var can_block = state_machine.current_state is SwordReadyState and is_on_floor()
	block_detector.monitoring = can_block
	if can_block:
		block_detector.scale.x = facing_direction

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

func _on_hurt_box_took_damage(damage: int, _is_heavy: bool = false) -> void:
	if invincible_timer > 0 or is_invincible or _is_dead:
		return

	_cancel_charge()

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
	_is_dead = true

	# 冻结所有运动
	velocity = Vector2.ZERO
	set_physics_process(false)
	set_process(false)

	# 禁用受伤框，防止死亡期间继续受伤
	hurtbox_collision.set_deferred("disabled", true)

	# 停止关卡 BGM
	AudioManager.pause_bgm()

	# 播放死亡动画
	animated_sprite.play("hurt")

	# 播放死亡音效
	AudioManager.play_sound(&"siwang")

	# 清除场景持久化，确保重开时恢复满状态
	PlayerStateManager.clear()

	# 等待 2.0 秒让死亡动画和音效播放一下
	await get_tree().create_timer(2.0).timeout

	# 切换到 GameOverScreen
	hide()
	const GameOverScreen = preload("res://scripts/ui/GameOverScreen.gd")
	GameOverScreen.return_scene = get_tree().current_scene.scene_file_path
	get_tree().change_scene_to_file("res://scenes/ui/GameOverScreen.tscn")


## 检测单面攀爬墙（Area2D 型），满足条件返回 true 且已切换状态
func check_climbable_wall() -> bool:
	var wall = current_climbable_wall
	if not wall:
		return false
	if not wall.can_climb(self):
		return false
	var normal_x = wall.get_wall_normal_x(global_position.x)
	if velocity.x * normal_x >= 0:
		return false
	state_machine.change_state($StateMachine/WallState, {"climbable_wall": wall})
	return true


# ────────── 灭杀链式计时（仅负责首次进入连斩状态）──────────
func _update_exterminate_chain(delta: float) -> void:
	if not exterminate_chain_active:
		return
	if state_machine.current_state is ExterminateChainState:
		return

	exterminate_chain_timer -= delta
	if exterminate_chain_timer <= 0:
		_end_exterminate_chain()
		return

	if Input.is_action_just_pressed("exterminate"):
		var target = _find_nearest_enemy_in_detector()
		if not target:
			return

		exterminate_chain_active = false
		state_machine.change_state(
			$StateMachine/ExterminateChainState,
			{"target": target, "chains": exterminate_remaining_chains}
		)


func _find_nearest_enemy_in_detector() -> Node2D:
	var nearest_dist = INF
	var nearest: Node2D = null

	var all_enemies = get_tree().get_nodes_in_group("enemy")
	for enemy in all_enemies:
		if not is_instance_valid(enemy) or _is_node_dead(enemy):
			continue
		if enemy == self:
			continue
		var dist = global_position.distance_squared_to(enemy.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = enemy

	return nearest


# ────────── 灭杀蓄力跟踪 ──────────
func _update_charge(delta: float) -> void:
	if state_machine.current_state is ExterminateChainState:
		return
	if Input.is_action_just_pressed("exterminate"):
		if sword.current_tp <= 0:
			return
		_charge_hold_time = 0.0
		exterminate_stacks = 0
		_charge_energy_timer = 0.0
		_charge_visual_active = false

	if Input.is_action_pressed("exterminate") and _charge_hold_time >= 0:
		_charge_hold_time += delta
		if _charge_hold_time >= 0.3:
			if not _charge_visual_active:
				_charge_visual_active = true
				_charge_sfx_player = AudioManager.play_sfx_fade_in(&"xuli", 0.0)
			_charge_energy_timer += delta
			_charge_mist_timer += delta
			if _charge_mist_timer >= randf_range(0.02, 0.05):
				_charge_mist_timer = 0.0
				_spawn_shaqi()
				_spawn_shaqi()
			if _charge_energy_timer >= 0.5 and exterminate_stacks < 7:
				if sword.current_tp >= 1:
					sword.current_tp -= 1
					sword.tp_changed.emit(sword.current_tp)
					exterminate_stacks += 1
					_charge_energy_timer -= 0.5
					_update_charge_color()
				else:
					_charge_energy_timer = 0.0
					_stop_charge_sfx()

	if Input.is_action_just_released("exterminate"):
		if _charge_hold_time >= 0.3:
			var current = state_machine.current_state
			if current is WallState or current is HangState:
				_cancel_charge()
				return
			if exterminate_stacks <= 0:
				_cancel_charge()
				return
			_stop_charge_sfx()
			animated_sprite.modulate = Color.WHITE
			var anim_name = "Exec_Stand"
			if current is JumpState or current is FallState:
				anim_name = "Exec_Air"
			elif current is CrouchState:
				anim_name = "Exec_Crouch"
			state_machine.change_state(
				$StateMachine/ExterminateReleaseState,
				{"energy": exterminate_stacks, "anim_name": anim_name}
			)
		else:
			_cancel_charge()

	if not Input.is_action_pressed("exterminate") and not Input.is_action_just_pressed("exterminate"):
		if _charge_hold_time >= 0:
			_cancel_charge()


func _spawn_shaqi() -> void:
	var s = Sprite2D.new()
	s.texture = _shaqi_texture
	s.modulate.a = randf_range(0.4, 0.7)
	var sc = randf_range(0.5, 0.9)
	s.scale = Vector2(sc, sc)
	s.position.x = randf_range(-12, 12)
	s.position.y = 0
	charge_mist.add_child(s)

	var rise = randf_range(30, 50)
	var duration = randf_range(0.4, 0.6)
	var tw = create_tween()
	tw.tween_property(s, "position:y", -rise, duration)
	tw.set_parallel(true)
	tw.tween_property(s, "modulate:a", 0.0, duration - 0.1)
	tw.tween_callback(s.queue_free).set_delay(duration)

#根据蓄力层数调整身体颜色
func _update_charge_color() -> void:
	if exterminate_stacks >= 7:
		animated_sprite.modulate = Color(0.3, 0, 0)
	elif exterminate_stacks >= 5:
		animated_sprite.modulate = Color(0.4, 0.2, 0.2)
	elif exterminate_stacks >= 3:
		animated_sprite.modulate = Color(0.6, 0.4, 0.4)
	elif exterminate_stacks >= 1:
		animated_sprite.modulate = Color(0.8, 0.65, 0.65)
	else:
		animated_sprite.modulate = Color(1, 1, 1)


func _cancel_charge() -> void:
	_stop_charge_sfx()
	_charge_hold_time = -1.0
	animated_sprite.modulate = Color.WHITE
	exterminate_stacks = 0
	_charge_visual_active = false


func _end_exterminate_chain() -> void:
	exterminate_chain_active = false
	exterminate_remaining_chains = 0
	exterminate_chain_timer = 0.0
	if invincible_timer <= 0 and not is_invincible:
		animated_sprite.modulate = Color.WHITE
		animated_sprite.modulate.a = 1.0


func _stop_charge_sfx() -> void:
	if _charge_sfx_player:
		_charge_sfx_player.stop()
		_charge_sfx_player = null


func _is_node_dead(node: Node2D) -> bool:
	if not is_instance_valid(node):
		return true
	if "is_dead" in node and node.is_dead:
		return true
	if "_is_dead" in node and node._is_dead:
		return true
	return false


func _on_block_detector_entered(area: Area2D) -> void:
	if not area.is_in_group("blockable"):
		return
	if not (state_machine.current_state is SwordReadyState):
		return
	# 判断是否来自正面
	var attack_dir = sign(area.global_position.x - global_position.x)
	if attack_dir != 0 and attack_dir != facing_direction:
		return
	AudioManager.play_sound(&"fangyu")
	_spawn_block_spark()
	var projectile = area.get_parent()
	if is_instance_valid(projectile):
		projectile.queue_free()


func _spawn_block_spark() -> void:
	for i in 5:
		var s = Sprite2D.new()
		s.texture = _spark_texture
		s.modulate = Color.WHITE
		s.scale = Vector2(randf_range(0.8, 1.5), randf_range(0.8, 1.5))
		s.rotation = randf_range(0, TAU)
		var start_pos = block_spark_pos.position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		s.position = start_pos
		s.z_index = 100
		add_child(s)
		var peak_x = start_pos.x + (-facing_direction) * randf_range(25, 50)
		var peak_y = start_pos.y - randf_range(15, 30)
		var land_y = peak_y + randf_range(25, 45)
		var rise_time = 0.1
		var fall_time = randf_range(0.12, 0.18)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "modulate:a", 0.0, rise_time + fall_time)
		tw.tween_property(s, "position", Vector2(peak_x, peak_y), rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "position:y", land_y, fall_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(rise_time)
		tw.tween_callback(s.queue_free).set_delay(rise_time + fall_time)
