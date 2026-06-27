extends BossState
class_name BossRushState

enum Phase { CHARGE, DASH, RECOVERY }

var _phase: int = Phase.CHARGE
var _charge_timer: float = 0.0
var _dash_timer: float = 0.0
var _recovery_timer: float = 0.0
var _shadow_timer: float = 0.0
var _shadows: Array[Sprite2D] = []
var hit_box: Area2D
var hit_enemies: Array[HurtBox] = []

const CHARGE_DURATION: float = 1.0    # 蓄力时间（秒），调小加速出招
const DASH_SPEED: float = 600.0       # 冲刺速度（像素/秒）
const MAX_DASH_TIME: float = 3.0      # 最大冲刺时间（秒），防止无限冲
const RECOVERY_DURATION: float = 0.8  # 冲刺后缓冲时间（秒）
const SHADOW_INTERVAL: float = 0.02   # 残影生成间隔（秒），越小残影越密
const SHADOW_ALPHA: float = 0.8       # 残影不透明度，1.0=全实
const SHADOW_FADE_TIME: float = 0.2   # 残影淡出时间（秒）

func enter(_msg: Dictionary = {}) -> void:
	if not boss.is_on_floor():
		state_machine.change_state_by_name("BossIdleState")
		return
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("rushcharge")
	boss.animated_sprite.modulate = Color(0.122, 0.271, 0.161, 1.0)
	_phase = Phase.CHARGE
	_charge_timer = CHARGE_DURATION
	_dash_timer = 0.0
	_recovery_timer = 0.0
	_shadow_timer = 0.0
	_shadows.clear()
	hit_enemies.clear()
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = boss.facing_direction
	_enable_rush_hitbox(false)

func update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			_charge_timer -= delta
			if _charge_timer <= 0.0:
				_execute_dash()

		Phase.DASH:
			_enable_rush_hitbox(true)
			if hit_box and hit_box.monitoring:
				var areas = hit_box.get_overlapping_areas()
				for area in areas:
					if area is HurtBox and not hit_enemies.has(area) and area != boss.hurt_box:
						hit_enemies.append(area)
						area.take_damage(boss.data.slash_damage)

		Phase.RECOVERY:
			_recovery_timer -= delta
			if _recovery_timer <= 0.0:
				_cleanup()
				state_machine.change_state_by_name("BossIdleState")

func physics_update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			boss.velocity.x = 0.0

		Phase.DASH:
			if not boss.is_ground_ahead() or _dash_timer >= MAX_DASH_TIME:
				boss.velocity.x = 0.0
				_enter_recovery()
				return
			boss.velocity.x = boss.facing_direction * DASH_SPEED
			_dash_timer += delta
			_shadow_timer += delta
			if _shadow_timer >= SHADOW_INTERVAL:
				_shadow_timer = 0.0
				_spawn_shadow()

		Phase.RECOVERY:
			boss.velocity.x = 0.0

func exit() -> void:
	_cleanup()

func _execute_dash() -> void:
	_phase = Phase.DASH
	_dash_timer = 0.0
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.play("rush")

func _enter_recovery() -> void:
	_phase = Phase.RECOVERY
	_recovery_timer = RECOVERY_DURATION
	boss.velocity = Vector2.ZERO
	_enable_rush_hitbox(false)
	boss.animated_sprite.play("rushcharge")

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

func _enable_rush_hitbox(enabled: bool) -> void:
	if not hit_box:
		var node = boss.get_node_or_null("AttackRoot/RushHitBox")
		if node:
			hit_box = node as Area2D
	if hit_box and hit_box.has_method("set_deferred"):
		hit_box.set_deferred("monitoring", enabled)

func _cleanup() -> void:
	for s in _shadows:
		if is_instance_valid(s):
			s.queue_free()
	_shadows.clear()
	_enable_rush_hitbox(false)
	hit_enemies.clear()
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		attack_root.scale.x = 1.0
	boss.animated_sprite.modulate = Color.WHITE

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)
