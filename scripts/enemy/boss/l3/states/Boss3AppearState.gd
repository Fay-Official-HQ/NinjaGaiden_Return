# res://scripts/enemy/boss/l3/states/Boss3AppearState.gd
extends Boss3State
class_name Boss3AppearState

enum Phase { FADE_OUT, HIDDEN, FADE_IN }

var _phase: int = Phase.FADE_OUT
var _timer: float = 0.0
var _appear_pos: Vector2

func enter(msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	boss.animated_sprite.play("jump")
	_disable_all_hitboxes()
	_phase = Phase.FADE_OUT
	_timer = 0.0
	boss.animated_sprite.modulate.a = 1.0
	_appear_pos = msg.get("target_pos", boss.global_position)

func update(delta: float) -> void:
	_timer += delta
	match _phase:
		Phase.FADE_OUT:
			boss.animated_sprite.modulate.a = 1.0 - (_timer / boss.data.appear_fade_out_time)
			if _timer >= boss.data.appear_fade_out_time:
				boss.animated_sprite.modulate.a = 0.0
				_phase = Phase.HIDDEN
				_timer = 0.0
		Phase.HIDDEN:
			if _timer >= boss.data.appear_hidden_time:
				boss.global_position = _appear_pos
				_phase = Phase.FADE_IN
				_timer = 0.0
		Phase.FADE_IN:
			boss.animated_sprite.modulate.a = _timer / boss.data.appear_fade_in_time
			if _timer >= boss.data.appear_fade_in_time:
				boss.animated_sprite.modulate.a = 1.0
				_restore_all_hitboxes()
				state_machine.change_state_by_name("Boss3IdleState")

func physics_update(_delta: float) -> void:
	boss.velocity = Vector2.ZERO

func exit() -> void:
	_phase = Phase.FADE_OUT
	boss.animated_sprite.modulate.a = 1.0

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
