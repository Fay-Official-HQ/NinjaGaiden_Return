extends State
class_name ExterminateReleaseState

var _energy: int = 0
var _killed_any: bool = false
var _hit_enemies: Array[HurtBox] = []
var _attack_root: Node2D
var _dash_box: SwordHitBox
var _release_timer: float = 0.0
var _execution_duration: float = 0.0
var _anim_name: String = "Exec_Air"

func enter(msg: Dictionary = {}) -> void:
	_energy = msg.get("energy", 0)
	_anim_name = msg.get("anim_name", "Exec_Air")
	_killed_any = false
	_hit_enemies.clear()
	_release_timer = 0.0

	var sprite = player.animation.sprite
	var frame_count = sprite.sprite_frames.get_frame_count(_anim_name)
	var speed = sprite.sprite_frames.get_animation_speed(_anim_name)
	_execution_duration = frame_count / speed

	player.animation.play(_anim_name)
	AudioManager.play_sound(&"bishaji")

	_attack_root = player.get_node("AttackRoot") as Node2D
	_dash_box = _attack_root.get_node("SwordDashBox") as SwordHitBox
	if _attack_root:
		_attack_root.scale.x = player.facing_direction

func update(delta: float) -> void:
	_release_timer += delta

	if _dash_box and not _dash_box.monitoring and _release_timer >= _execution_duration * 0.33:
		_dash_box.set_deferred("monitoring", true)

	if _dash_box and _dash_box.monitoring:
		var areas = _dash_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not _hit_enemies.has(area):
				_hit_enemies.append(area)
				var damage = 1 + _energy
				area.take_damage(damage)
				var enemy = area.owner
				if is_instance_valid(enemy):
					var dead = ("is_dead" in enemy and enemy.is_dead) or ("_is_dead" in enemy and enemy._is_dead)
					if dead:
						_killed_any = true

	if _release_timer >= _execution_duration:
		_cleanup()
		if _killed_any and _energy > 0:
			player.exterminate_remaining_chains = _energy
			player.exterminate_chain_timer = 0.5
			player.exterminate_chain_active = true
		if player.is_on_floor():
			state_machine.change_state(player.idle_state)
		else:
			state_machine.change_state(player.fall_state)
		return

func physics_update(_delta: float) -> void:
	player.velocity.x = 0.0
	player.velocity.y = 0.0
	player.move_and_slide()

func exit() -> void:
	_cleanup()

func _cleanup() -> void:
	if _dash_box:
		_dash_box.set_deferred("monitoring", false)
	_hit_enemies.clear()
	if _attack_root:
		_attack_root.scale.x = 1.0
	if not _killed_any or _energy <= 0:
		player._end_exterminate_chain()
