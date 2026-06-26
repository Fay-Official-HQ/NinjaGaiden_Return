extends Area2D

class_name DeathZone


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.die()
	elif body is Boss:
		body.trigger_appear_if_alive()
