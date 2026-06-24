extends BossState
class_name BossIdleState

func enter(_msg: Dictionary = {}) -> void:
	boss.animated_sprite.play("idle")
	boss.velocity = Vector2.ZERO

func update(_delta: float) -> void:
	if not boss.player_ref:
		return
	var dist_x = abs(boss.player_ref.global_position.x - boss.global_position.x)
	if dist_x < 60.0:
		state_machine.change_state_by_name("BossSlashState")
