extends State
class_name ExterminateChainState

const CHAIN_WINDOW = 0.3
const MAX_CHAIN_DISTANCE = 240.0

var _chains_remaining: int = 0
var _chain_timer: float = 0.0
var _is_active: bool = false

# 残影贴图从角色素材配置读取（player.get_shadow_textures()），每个角色可不同
var _active_shadows: Array[Sprite2D] = []

var _chain_origin: Vector2


func enter(msg: Dictionary = {}) -> void:
	player._cancel_charge()

	# 清除受伤闪烁计时器：防止 _process 中 invincible_timer 每帧覆盖
	# modulate.a（0.5/1.0 交替），导致灭杀隐身（modulate.a=0）失效
	player.invincible_timer = 0.0

	_chains_remaining = msg.get("chains", 0)
	_is_active = true
	_chain_timer = CHAIN_WINDOW
	_chain_origin = player.global_position

	player.animated_sprite.modulate.a = 0.0
	player.is_invincible = true
	player.is_gravity_disabled = true
	player.velocity = Vector2.ZERO


func update(_delta: float) -> void:
	if not _is_active:
		return

	_chain_timer -= _delta
	if _chain_timer <= 0:
		_finish_chain()
		return

	if Input.is_action_just_pressed("exterminate"):
		if _chains_remaining <= 0:
			_finish_chain()
			return
		var target = player._find_nearest_enemy_in_detector()
		if not target:
			_finish_chain()
			return
		if target.global_position.distance_to(_chain_origin) > MAX_CHAIN_DISTANCE:
			_finish_chain()
			return
		_chains_remaining -= 1
		_chain_timer = CHAIN_WINDOW
		_do_attack(target)


func physics_update(_delta: float) -> void:
	if not _is_active:
		return
	player.velocity.x = 0.0
	player.move_and_slide()


func exit() -> void:
	_is_active = false
	_cleanup_shadows()
	player.is_invincible = false
	# 恢复角色可见（防止灭杀被强制切走时残留透明）
	player.animated_sprite.modulate = Color.WHITE


func _do_attack(target: Node2D) -> void:
	if not is_instance_valid(target) or _is_node_dead(target):
		_finish_chain()
		return

	if player.sword.current_tp <= 0:
		_finish_chain()
		return
	player.sword.current_tp -= 1
	player.sword.tp_changed.emit(player.sword.current_tp)

	player.set_facing_direction(1.0 if target.global_position.x > player.global_position.x else -1.0)

	player.play_sound(&"cuoa")
	_spawn_shadow_wave(target.global_position)

	var hurtbox = _get_hurtbox(target)
	if hurtbox:
		hurtbox.take_damage(1)


func _spawn_shadow_wave(pos: Vector2) -> void:
	var textures: Array = player.get_shadow_textures()
	var tex = textures[randi() % textures.size()]
	var s = Sprite2D.new()
	s.texture = tex
	s.modulate.a = randf_range(0.4, 0.7)
	s.scale.x = 1.0 if randf() > 0.5 else -1.0
	s.rotation = deg_to_rad(randf_range(-15, 15))
	s.scale *= randf_range(0.9, 1.1)

	var world = player.get_parent()
	world.add_child(s)
	s.global_position = pos + Vector2(randf_range(-40, 40), randf_range(-30, 30))
	s.z_index = 50
	_active_shadows.append(s)

	var tree = player.get_tree()
	var tw = tree.create_tween()
	tw.tween_interval(2.5)
	tw.tween_property(s, "modulate:a", 0.0, 0.5)
	tw.tween_callback(_remove_shadow.bind(s))


func _finish_chain() -> void:
	_is_active = false
	_cleanup_shadows()
	player.exterminate_chain_active = false
	player.exterminate_remaining_chains = 0
	player.exterminate_chain_timer = 0.0

	player.global_position.y -= 20

	var sprite = player.animated_sprite
	sprite.modulate = Color.CYAN
	sprite.modulate.a = 1.0
	sprite.position.x = -20.0
	player.animation.play("fall")

	var tree = player.get_tree()
	var fade = tree.create_tween().set_parallel(true)
	fade.tween_property(sprite, "modulate", Color.WHITE, 0.5)
	fade.tween_property(sprite, "position:x", 0.0, 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

	var shake = tree.create_tween()
	shake.tween_property(sprite, "position:x", 12.0, 0.04)
	shake.tween_property(sprite, "position:x", -10.0, 0.04).set_delay(0.04)
	shake.tween_property(sprite, "position:x", 6.0, 0.04).set_delay(0.08)
	shake.tween_property(sprite, "position:x", -4.0, 0.04).set_delay(0.12)
	shake.tween_callback(func():
		player.is_invincible = false
		player.is_gravity_disabled = false
		state_machine.change_state(player.fall_state)
	)


func _remove_shadow(s) -> void:
	if not is_instance_valid(s):
		return
	_active_shadows.erase(s)
	s.queue_free()


func _cleanup_shadows() -> void:
	for s in _active_shadows:
		if not is_instance_valid(s):
			continue
		if s.has_meta(&"fading"):
			continue
		s.set_meta(&"fading", true)
		var tree = player.get_tree()
		var tw = tree.create_tween()
		tw.tween_property(s, "modulate:a", 0.0, 0.5)
		tw.tween_callback(_remove_shadow.bind(s))
	_active_shadows.clear()


func _get_hurtbox(target: Node2D) -> HurtBox:
	if "hurtbox" in target and target.hurtbox is HurtBox:
		return target.hurtbox
	var node = target.get_node_or_null("HurtBox")
	return node as HurtBox


func _is_node_dead(node: Node2D) -> bool:
	if not is_instance_valid(node):
		return true
	if "is_dead" in node and node.is_dead:
		return true
	if "_is_dead" in node and node._is_dead:
		return true
	return false
