extends BossState
class_name BossAppearState

enum Phase { FADE_OUT, HIDDEN, FADE_IN }

var _phase: int = Phase.FADE_OUT
var _timer: float = 0.0
var _appear_pos: Vector2

const FADE_OUT_TIME: float = 1.0
const HIDDEN_TIME: float = 2.0
const FADE_IN_TIME: float = 1.0

func enter(msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("appear")
	_disable_all_hitboxes()
	_phase = Phase.FADE_OUT
	_timer = 0.0
	boss.animated_sprite.modulate.a = 1.0
	_appear_pos = msg.get("target_pos", boss.global_position)

func update(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.FADE_OUT:
			boss.animated_sprite.modulate.a = 1.0 - (_timer / FADE_OUT_TIME)
			if _timer >= FADE_OUT_TIME:
				boss.animated_sprite.modulate.a = 0.0
				_phase = Phase.HIDDEN
				_timer = 0.0
		Phase.HIDDEN:
			if _timer >= HIDDEN_TIME:
				boss.global_position = _appear_pos
				_phase = Phase.FADE_IN
				_timer = 0.0
		Phase.FADE_IN:
			boss.animated_sprite.modulate.a = _timer / FADE_IN_TIME
			if _timer >= FADE_IN_TIME:
				boss.animated_sprite.modulate.a = 1.0
				_restore_all_hitboxes()
				state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.velocity = Vector2.ZERO

func _disable_all_hitboxes() -> void:
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		for child in attack_root.get_children():
			if child is Area2D:
				child.set_deferred("monitoring", false)

func _restore_all_hitboxes() -> void:
	var attack_root = boss.get_node_or_null("AttackRoot") as Node2D
	if attack_root:
		for child in attack_root.get_children():
			if child is Area2D:
				child.set_deferred("monitoring", true)

func exit() -> void:
	_phase = Phase.FADE_OUT
	boss.animated_sprite.modulate.a = 1.0
