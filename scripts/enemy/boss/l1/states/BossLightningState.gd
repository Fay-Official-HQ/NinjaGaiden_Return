extends BossState
class_name BossLightningState

enum Phase { CROUCH_CHARGE, JUMP, VANISH, STRIKES, DONE }

var _phase: int = Phase.CROUCH_CHARGE
var _timer: float = 0.0
var _strike_count: int = 0
var _finish_timer: float = 0.0
var _reappear_tween: Tween
const CROUCH_DURATION: float = 1.0
const JUMP_VELOCITY_Y: float = -500.0
const VANISH_DURATION: float = 1.0
const STRIKE_INTERVAL: float = 0.8
const DONE_DELAY: float = 1.0
const REAPPEAR_FADE_TIME: float = 0.5
const LIGHTNING_Y: float = 41.0

var _bolt_scene: PackedScene = preload("res://scenes/enemy/boss/LightningBolt.tscn")

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("crouch")
	_phase = Phase.CROUCH_CHARGE
	_timer = CROUCH_DURATION
	_strike_count = 0

func update(delta: float) -> void:
	_timer -= delta
	match _phase:
		Phase.CROUCH_CHARGE:
			if _timer <= 0.0:
				boss.velocity.y = JUMP_VELOCITY_Y
				boss.velocity.x = 0.0
				boss.animated_sprite.play("jump")
				_phase = Phase.JUMP

		Phase.JUMP:
			if boss.velocity.y >= -20.0:
				boss.velocity = Vector2.ZERO
				boss.ignore_gravity = true
				boss.is_invincible = true
				boss.animated_sprite.play("vanish")
				_phase = Phase.VANISH
				_timer = VANISH_DURATION

		Phase.VANISH:
			var progress = 1.0 - _timer / VANISH_DURATION
			boss.animated_sprite.modulate.a = clamp(1.0 - progress, 0.0, 1.0)
			if _timer <= 0.0:
				boss.animated_sprite.modulate.a = 0.0
				_phase = Phase.STRIKES
				_timer = 0.0
				_strike_count = 0

		Phase.STRIKES:
			if _timer <= 0.0:
				_strike_count += 1
				_summon_lightning(_strike_count)
				if _strike_count < 3:
					_timer = STRIKE_INTERVAL
				else:
					_phase = Phase.DONE
					_finish_timer = DONE_DELAY

		Phase.DONE:
			if _finish_timer > 0.0:
				_finish_timer -= delta
			else:
				_reappear()

func physics_update(_delta: float) -> void:
	match _phase:
		Phase.CROUCH_CHARGE, Phase.VANISH, Phase.STRIKES, Phase.DONE:
			boss.velocity.x = 0.0

func exit() -> void:
	boss.is_invincible = false
	boss.ignore_gravity = false
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.modulate.a = 1.0
	if _reappear_tween and _reappear_tween.is_valid():
		_reappear_tween.kill()

func _summon_lightning(strike_num: int) -> void:
	var player = boss.player_ref
	if not player:
		return
	var bolt = _bolt_scene.instantiate()
	var pos_x = player.global_position.x + randf_range(-30.0, 30.0)
	bolt.global_position = Vector2(pos_x, LIGHTNING_Y)
	get_tree().current_scene.add_child(bolt)
	print("【BossLightning】召唤第 %d 道雷电" % strike_num)

func _reappear() -> void:
	boss.is_invincible = false
	boss.ignore_gravity = false
	boss.velocity = Vector2.ZERO
	boss.global_position = boss.appear_target_pos
	boss.move_and_slide()
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.modulate.a = 0.0
	boss.animated_sprite.play("appear")
	_reappear_tween = create_tween()
	_reappear_tween.tween_property(boss.animated_sprite, "modulate:a", 1.0, REAPPEAR_FADE_TIME)
	_reappear_tween.tween_callback(func():
		_phase = Phase.CROUCH_CHARGE
		state_machine.change_state_by_name("BossIdleState")
	)
