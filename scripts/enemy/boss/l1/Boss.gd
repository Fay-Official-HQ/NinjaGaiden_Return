extends CharacterBody2D
class_name Boss

@export var data: BossData
## 显现技能出现的固定位置坐标（由 BossSpawner 自动传入或在关卡场景中手动设置）
@export var appear_target_pos: Vector2
## BOSS 掉落触发展现的 Y 轴阈值，超过此值自动触发 Appear
@export var fall_dead_y: float = 200.0

@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtRoot/HurtBox
@onready var state_machine: BossStateMachine = $BossStateMachine
@onready var boss_ui: BossUI = $BossUI
@onready var ai_component: BossAIComponent = $Components/BossAIComponent

var player_ref: Player
var current_hp: int
var is_dead: bool = false
var facing_direction: float = 1.0
var _flash_tween: Tween
## 由 BossSpawner 在实例化后、add_child 前设置，表示首次生成
var _spawn_point: Vector2

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	ai_component.initialize(self)
	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.play("appear")
		animated_sprite.modulate.a = 0.0
		_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += 980.0 * delta
	var prev_x = global_position.x
	state_machine.physics_update(delta)
	move_and_slide()
	if not is_dead and abs(velocity.x) < 1.0:
		global_position.x = prev_x
	if not is_dead and global_position.y > fall_dead_y:
		trigger_appear_if_alive()

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead:
		return
	if state_machine.current_state is BossAppearState:
		return
	if not (state_machine.current_state is BossBlockState) and is_on_floor() and _is_player_in_front():
		if not _is_player_using_finish() and randf() < 0.5:
			state_machine.change_state_by_name("BossBlockState")
			return
	if state_machine.current_state is BossBlockState and _is_player_in_front():
		print("【Boss】正面格挡")
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	if current_hp <= 0:
		state_machine.change_state_by_name("BossDeathState")
	elif is_heavy:
		state_machine.change_state_by_name("BossHurtState")
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

func trigger_appear_if_alive() -> void:
	if is_dead:
		return
	if state_machine.current_state is BossAppearState:
		return
	state_machine.change_state_by_name("BossAppearState", {"target_pos": appear_target_pos})

func _tween_spawn_in() -> void:
	var tw = create_tween()
	tw.tween_property(animated_sprite, "modulate:a", 1.0, 1.0)
	tw.tween_callback(func():
		state_machine.start()
	)


func die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

func _is_player_using_finish() -> bool:
	if not player_ref:
		return false
	var player_state = player_ref.state_machine.current_state
	return player_state is DragonFlashState

func _is_player_in_front() -> bool:
	if not player_ref:
		return false
	if facing_direction > 0:
		return player_ref.global_position.x > global_position.x
	else:
		return player_ref.global_position.x < global_position.x

func get_ground_at(x_pos: float) -> Vector2:
	var space_state = get_world_2d().direct_space_state
	var from = Vector2(x_pos, global_position.y - 10.0)
	var to = Vector2(x_pos, global_position.y + 200.0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	if result.is_empty():
		return Vector2(x_pos, global_position.y + 200.0)
	return result.position

func is_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(0, 0)
	var to = global_position + Vector2(facing_direction * 50.0, 40.0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	return not result.is_empty()
