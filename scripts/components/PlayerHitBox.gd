# res://scripts/components/PlayerHitBox.gd
extends AttackHitBox

class_name PlayerHitBox

@export var damage: int = 1

func _on_hit_enemy(hurtbox: HurtBox) -> void:
	if _is_blocked(hurtbox):
		return
	var player = owner as Player
	if player and player.sword:
		player.sword.add_tp(1)

func _is_blocked(hurtbox: HurtBox) -> bool:
	var target = hurtbox.owner
	if target is Boss:
		return target.state_machine.current_state is BossBlockState and target._is_player_in_front()
	return false
