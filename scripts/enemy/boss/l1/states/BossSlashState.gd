extends BossState
class_name BossSlashState

enum Phase { CHARGE, ATTACK }

var _phase: int = Phase.CHARGE
var _charge_timer: float = 0.0
var hit_box: Area2D
var hit_enemies: Array[HurtBox] = []
var _lunge_velocity: float = 0.0
var _shadow_timer: float = 0.0
var _shadows: Array[Sprite2D] = []

const CHARGE_DURATION: float = 0.4
const LUNGE_FRICTION: float = 800.0
const SHADOW_INTERVAL: float = 0.04
const SHADOW_ALPHA: float = 0.5
const SHADOW_FADE_TIME: float = 0.15

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("attackcharge")
	boss.animated_sprite.modulate = Color(0.122, 0.271, 0.161, 1.0)
	_phase = Phase.CHARGE
	_charge_timer = CHARGE_DURATION
	_lunge_velocity = 0.0
	_shadow_timer = 0.0
	_shadows.clear()
	hit_enemies.clear()
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = boss.facing_direction
	var node = boss.get_node_or_null("AttackRoot/SlashHitBox")
	if node:
		hit_box = node as Area2D
		if hit_box.has_method("set_deferred"):
			hit_box.set_deferred("monitoring", false)

func update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_execute_attack()

		Phase.ATTACK:
			if hit_box and hit_box.monitoring:
				var areas = hit_box.get_overlapping_areas()
				for area in areas:
					if area is HurtBox and not hit_enemies.has(area) and area != boss.hurt_box:
						hit_enemies.append(area)
						area.take_damage(boss.data.slash_damage)
			var sprite = boss.animated_sprite
			if sprite.animation == "attack" and not sprite.is_playing():
				_cleanup()
				state_machine.change_state_by_name("BossIdleState")

func physics_update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			boss.velocity.x = 0.0
		Phase.ATTACK:
			if _lunge_velocity != 0.0:
				if boss.is_ground_ahead():
					boss.velocity.x = _lunge_velocity
					_lunge_velocity = move_toward(_lunge_velocity, 0.0, LUNGE_FRICTION * delta)
				else:
					boss.velocity.x = 0.0
					_lunge_velocity = 0.0
			_shadow_timer += delta
			if _shadow_timer >= SHADOW_INTERVAL:
				_shadow_timer = 0.0
				_spawn_shadow()

func exit() -> void:
	_cleanup()

func _execute_attack() -> void:
	_phase = Phase.ATTACK
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.play("attack")
	if hit_box:
		hit_box.set_deferred("monitoring", true)
	if boss.is_ground_ahead():
		_lunge_velocity = boss.facing_direction * sqrt(2.0 * LUNGE_FRICTION * boss.data.slash_lunge_distance)
	else:
		_lunge_velocity = 0.0

func _spawn_shadow() -> void:
	var sprite := Sprite2D.new()
	sprite.texture = boss.animated_sprite.sprite_frames.get_frame_texture(boss.animated_sprite.animation, boss.animated_sprite.frame)
	sprite.global_position = boss.global_position
	sprite.scale = boss.animated_sprite.scale
	sprite.flip_h = boss.animated_sprite.flip_h
	sprite.modulate = Color(1.0, 1.0, 1.0, SHADOW_ALPHA)
	boss.get_parent().add_child(sprite)
	_shadows.append(sprite)
	var tw = create_tween()
	tw.tween_property(sprite, "modulate:a", 0.0, SHADOW_FADE_TIME)
	tw.tween_callback(sprite.queue_free)

func _cleanup() -> void:
	for s in _shadows:
		if is_instance_valid(s):
			s.queue_free()
	_shadows.clear()
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = 1.0
	boss.animated_sprite.modulate = Color.WHITE

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)
