# res://scripts/enemy/states/EnemyState.gd
extends Node

class_name EnemyState

var enemy: Enemy
var state_machine: EnemyStateMachine

func enter(msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass
