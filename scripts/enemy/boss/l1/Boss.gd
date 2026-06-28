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
var is_invincible: bool = false
var ignore_gravity: bool = false
var facing_direction: float = 1.0
var is_enhanced: bool = false
var _is_ninjutsu_overdrive: bool = false
var _lightning_triggered: bool = false
var _flash_tween: Tween
var _overdrive_timer: float = 0.0
var _gold_overlay: Sprite2D
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
	get_tree().create_timer(1.0).timeout.connect(func():
		AudioManager.play_sound(&"zhandou1")
	, CONNECT_ONE_SHOT)
	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.play("appear")
		animated_sprite.modulate.a = 0.0
		_create_gold_overlay()
	_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)
	_sync_gold_overlay()
	if _is_ninjutsu_overdrive:
		_overdrive_timer -= delta
		if _overdrive_timer <= 0.0:
			_deactivate_ninjutsu_overdrive()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not ignore_gravity and not is_on_floor():
		velocity.y += 980.0 * delta
	var prev_x = global_position.x
	state_machine.physics_update(delta)
	move_and_slide()
	if not is_dead and abs(velocity.x) < 1.0:
		global_position.x = prev_x
	if not is_dead and global_position.y > fall_dead_y:
		trigger_appear_if_alive()

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is BossAppearState:
		return
	if is_on_floor() and _is_player_in_front():
		var block_chance = _get_block_chance()
		if not _is_player_using_finish() and randf() < block_chance:
			if is_enhanced:
				AudioManager.play_sound(&"fangyu")
				var dist = abs(player_ref.global_position.x - global_position.x)
				state_machine.change_state_by_name("BossBlockState", {"counter": dist < 50.0})
				return
			elif state_machine.current_state is BossIdleState:
				AudioManager.play_sound(&"fangyu")
				state_machine.change_state_by_name("BossBlockState")
				return
	if state_machine.current_state is BossBlockState and _is_player_in_front():
		AudioManager.play_sound(&"fangyu")
		print("【Boss】正面格挡")
		return
	if state_machine.current_state.name == "BossWalkState" and _is_player_in_front():
		AudioManager.play_sound(&"fangyu")
		print("【Boss】移动格挡")
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	_update_enhancement_state()
	AudioManager.play_sound(&"shoushang")
	if current_hp > 0 and current_hp < 24 and not _lightning_triggered and not (state_machine.current_state is BossLightningState):
		_lightning_triggered = true
		print("【Boss】首次受伤且HP<24，触发必杀技")
		state_machine.change_state_by_name("BossLightningState")
		return
	if current_hp <= 0:
		var director = get_node_or_null("BossUI/BossDeathDirector") as BossDeathDirector
		if director:
			director.play_death_sequence(self)
		else:
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
	is_enhanced = false
	_is_ninjutsu_overdrive = false
	_lightning_triggered = false
	_overdrive_timer = 0.0
	_hide_gold_overlay()
	animated_sprite.self_modulate = Color.WHITE
	set_physics_process(false)
	set_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

func _create_gold_overlay() -> void:
	_gold_overlay = Sprite2D.new()
	_gold_overlay.name = "GoldOverlay"
	var mat = CanvasItemMaterial.new()
	mat.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_gold_overlay.material = mat
	_gold_overlay.modulate = Color(1.0, 0.6, 0.0, 0.6)
	_gold_overlay.centered = animated_sprite.centered
	_gold_overlay.visible = false
	animated_sprite.add_child(_gold_overlay)

func _sync_gold_overlay() -> void:
	if not _gold_overlay or not _gold_overlay.visible:
		return
	_gold_overlay.texture = animated_sprite.sprite_frames.get_frame_texture(animated_sprite.animation, animated_sprite.frame)
	_gold_overlay.flip_h = animated_sprite.flip_h

func _show_gold_overlay() -> void:
	if _gold_overlay:
		_gold_overlay.visible = true

func _hide_gold_overlay() -> void:
	if _gold_overlay:
		_gold_overlay.visible = false

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

func activate_ninjutsu_overdrive() -> void:
	_is_ninjutsu_overdrive = true
	_overdrive_timer = 5.0
	_show_gold_overlay()

func _deactivate_ninjutsu_overdrive() -> void:
	_is_ninjutsu_overdrive = false
	_overdrive_timer = 0.0
	if is_enhanced:
		_show_gold_overlay()
	else:
		_hide_gold_overlay()

## 当血量 ≤10 时进入强化状态，身体变为金黄色
func _update_enhancement_state() -> void:
	var should_enhance = current_hp <= 10 and current_hp > 0
	if should_enhance and not is_enhanced:
		is_enhanced = true
		if not _is_ninjutsu_overdrive:
			_show_gold_overlay()
		print("【Boss】进入强化状态 - 金色")
	elif not should_enhance and is_enhanced:
		is_enhanced = false
		if not _is_ninjutsu_overdrive:
			_hide_gold_overlay()
		print("【Boss】退出强化状态")

## 根据当前血量返回格挡概率
func _get_block_chance() -> float:
	if _is_ninjutsu_overdrive:
		return 0.8
	if current_hp <= 10:
		return 0.8
	elif current_hp <= 23:
		return 0.3
	return 0.15

func is_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(0, 0)
	var to = global_position + Vector2(facing_direction * 50.0, 40.0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	return not result.is_empty()
