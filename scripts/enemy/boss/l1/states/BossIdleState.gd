extends BossState
class_name BossIdleState

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("idle")
	boss.velocity = Vector2.ZERO

func update(_delta: float) -> void:
	if not boss.player_ref:
		return
	_face_player()
	var dist_x = abs(boss.player_ref.global_position.x - boss.global_position.x)
	if dist_x < 70.0:
		state_machine.change_state_by_name("BossSlashState")

func _face_player() -> void:
	var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(dir)
