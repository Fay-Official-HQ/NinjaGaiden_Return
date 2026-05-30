extends Node

class_name MovementComponent


var player: Player


func initialize(owner_player: Player) -> void:
	player = owner_player


func move(direction: float) -> void:
	player.velocity.x = direction * player.data.walk_speed



func stop() -> void:
	player.velocity.x = 0.0


func jump() -> void:
	player.velocity.y =-player.data.jump_force


func apply_gravity(delta: float) -> void:

	if not player.is_on_floor():
		player.velocity.y +=player.data.gravity * delta
