extends Area2D

class_name TransitionZone

@export var target_scene: String = ""

func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if target_scene != "":
			get_tree().change_scene_to_file(target_scene)
		else:
			push_error("TransitionZone: target_scene 为空，无法切换场景")
