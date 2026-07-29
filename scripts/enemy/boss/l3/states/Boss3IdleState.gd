# res://scripts/enemy/boss/l3/states/Boss3IdleState.gd
extends Boss3State
class_name Boss3IdleState

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.animated_sprite.play("idle")

func update(_delta: float) -> void:
	if not boss.player_ref:
		return
	_face_player()
	var action_name = boss.ai_component.get_next_action()
	if action_name != "":
		state_machine.change_state_by_name(action_name)

func physics_update(_delta: float) -> void:
	boss.velocity.x = 0.0
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * _delta
	boss.move_and_slide()
