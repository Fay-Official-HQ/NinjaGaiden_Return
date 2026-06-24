extends Node
class_name BossState

var boss: Boss
var state_machine: BossStateMachine

func enter(_msg: Dictionary = {}) -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
