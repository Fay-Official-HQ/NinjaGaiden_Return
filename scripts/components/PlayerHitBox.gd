# res://scripts/components/PlayerHitBox.gd
extends AttackHitBox

class_name PlayerHitBox

@export var damage: int = 1

func _on_hit_enemy(_hurtbox: HurtBox) -> void:
	var player = owner as Player
	if player and player.sword:
		player.sword.add_tp(1)
