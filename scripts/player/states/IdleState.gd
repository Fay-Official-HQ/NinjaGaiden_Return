extends State

class_name IdleState


func enter() -> void:

	print("进入 Idle")


func update(_delta: float) -> void:

	pass


func physics_update(_delta: float) -> void:

	pass


func exit() -> void:
	print("离开 Idle")
