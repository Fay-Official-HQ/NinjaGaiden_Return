extends State
class_name ExterminateChainState

var _target: Node2D
var _chains_left: int = 0
var _execution_duration: float = 0.0
var _timer: float = 0.0
var _has_dealt_damage: bool = false

func enter(msg: Dictionary = {}) -> void:
	_target = msg.get("target", null)
	_chains_left = msg.get("chains", 0) - 1

	if not is_instance_valid(_target) or _is_node_dead(_target):
		player._end_exterminate_chain()
		state_machine.change_state(_recover_state())
		return

	var sprite = player.animation.sprite
	var frame_count = sprite.sprite_frames.get_frame_count("Exec_Air")
	var speed = sprite.sprite_frames.get_animation_speed("Exec_Air")
	_execution_duration = frame_count / speed
	_timer = 0.0
	_has_dealt_damage = false

	var offset_x = 20.0 * (-1.0 if _target.global_position.x > player.global_position.x else 1.0)
	player.global_position = _target.global_position + Vector2(offset_x, -8.0)
	player.set_facing_direction(1.0 if _target.global_position.x > player.global_position.x else -1.0)

	player.animation.play("Exec_Air")
	AudioManager.play_sound(&"gongji")

	player.is_invincible = true

func update(delta: float) -> void:
	_timer += delta

	# 在动画 33% 处造成伤害
	if not _has_dealt_damage and _timer >= _execution_duration * 0.33:
		_has_dealt_damage = true
		if is_instance_valid(_target) and not _is_node_dead(_target):
			var hurtbox = _target.get_node_or_null("HurtBox") if "hurtbox" not in _target else _target.hurtbox
			if hurtbox is HurtBox:
				hurtbox.take_damage(1)

	if _timer >= _execution_duration:
		var killed = not is_instance_valid(_target) or _is_node_dead(_target)
		if killed and _chains_left > 0:
			player.exterminate_remaining_chains = _chains_left
			player.exterminate_chain_timer = 0.5
			player.exterminate_chain_active = true
		else:
			player._end_exterminate_chain()
		state_machine.change_state(_recover_state())

func physics_update(_delta: float) -> void:
	player.velocity = Vector2.ZERO
	player.move_and_slide()

func exit() -> void:
	player.is_invincible = false

func _recover_state() -> State:
	if player.is_on_floor():
		return player.idle_state
	else:
		return player.fall_state


func _is_node_dead(node: Node2D) -> bool:
	if not is_instance_valid(node):
		return true
	if "is_dead" in node and node.is_dead:
		return true
	if "_is_dead" in node and node._is_dead:
		return true
	return false
