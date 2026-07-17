extends Boss
class_name Boss_2

var _camera_ref: Camera2D
var _camera_offset: Vector2
## 是否启用摄像机锚点校正（HurtState 时临时禁用）
var _anchor_enabled: bool = true

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	ai_component.initialize(self)
	_camera_ref = get_viewport().get_camera_2d()

	# 飞行怪物穿透所有地形（移除 Platform/stop/ClimbableWall 碰撞）
	collision_mask = 16  # 只保留 PlayerAttack 层

	if _spawn_point != Vector2():
		state_machine.defer_start()
		global_position = _spawn_point
		if player_ref:
			set_facing_direction(-1.0 if player_ref.global_position.x < global_position.x else 1.0)
		animated_sprite.play("appear")
		animated_sprite.modulate.a = 0.0

	# 记录初始摄像机锚点偏移
	if _camera_ref:
		_camera_offset = global_position - _camera_ref.global_position
	else:
		_camera_offset = Vector2(data.camera_offset_x, data.camera_offset_y)

	_tween_spawn_in()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)
	_sync_gold_overlay()

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	state_machine.physics_update(delta)
	move_and_slide()
	# 不再全局锚定，由状态自己控制（IdleState 锚定，FlyState 自由飞行）

func _apply_camera_anchor() -> void:
	if not _anchor_enabled or not _camera_ref:
		return
	var anchor_x = _camera_ref.global_position.x + _camera_offset.x
	# 只在水平方向锚定，垂直方向留自由给 FlyState 正弦波
	global_position.x = anchor_x

## 供外部（FireWall enter_completed信号）调用，正式锚定摄像机位置
func start_boss_battle() -> void:
	if _camera_ref:
		_camera_offset = global_position - _camera_ref.global_position
	_anchor_enabled = true

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	if state_machine.current_state is BossAppearState:
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	_update_enhancement_state()
	AudioManager.play_sound(&"shoushang")
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

func _get_block_chance() -> float:
	return 0.0

func is_ground_ahead() -> bool:
	return true

func get_ground_at(x_pos: float) -> Vector2:
	return Vector2(x_pos, global_position.y)
