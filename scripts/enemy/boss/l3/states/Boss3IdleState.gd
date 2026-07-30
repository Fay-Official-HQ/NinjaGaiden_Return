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
