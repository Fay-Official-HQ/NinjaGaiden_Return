extends Area2D

class_name DeathZone


func _ready() -> void:
	collision_mask = 3
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
		return
	if body is Boss:
		body.trigger_appear_if_alive()
		return
	if body.is_in_group("fall_vulnerable"):
		var hurt_box = body.get_node_or_null("HurtBox") as HurtBox
		if hurt_box:
			hurt_box.take_damage(1)
