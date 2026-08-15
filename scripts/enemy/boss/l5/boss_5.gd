extends Boss
class_name Boss_5

## 能量球动画（供后续技能使用）
@onready var energy_animated: AnimatedSprite2D = $Visual/EnergyAnimated
## 发射点根节点（跟随面朝镜像翻转，保证 Marker2D1 位置始终正确）
@onready var mark_node: Node2D = $Mark


func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()
	ai_component.initialize(self)

	# 飞行 BOSS：穿透所有地形，只保留 PlayerAttack 碰撞层
	collision_mask = 16

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
	# 无重力飞行：位置由各状态（如 Boss5FlyState）直接控制
	state_machine.physics_update(delta)
	move_and_slide()


func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead or is_invincible:
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
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


## 受伤闪白：比基类更强的过曝白闪（参数在 BossData_5 中调节，我需要调试）
func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	var data5 := data as BossData_5
	var peak: float = data5.hurt_flash_strength if data5 else 6.0
	var mid: float = data5.hurt_flash_mid if data5 else 4.0
	var decay: float = data5.hurt_flash_decay if data5 else 0.15
	_flash_tween = create_tween()
	animated_sprite.modulate = Color(peak, peak, peak, 1.0)
	_flash_tween.tween_property(animated_sprite, "modulate", Color(mid, mid, mid, 1.0), 0.05)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, decay)


func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animated_sprite.flip_h = facing_direction < 0
	if energy_animated:
		energy_animated.flip_h = facing_direction < 0
		energy_animated.position.x = 26 * facing_direction
	# Mark 及其下所有子节点（Marker2D1 等）跟随面朝镜像翻转
	if mark_node:
		mark_node.scale.x = facing_direction


func is_ground_ahead() -> bool:
	return true


func get_ground_at(x_pos: float) -> Vector2:
	return Vector2(x_pos, global_position.y)
