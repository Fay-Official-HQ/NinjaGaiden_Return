extends Node
class_name BossState

var boss: Boss
var state_machine: BossStateMachine

func enter(_msg: Dictionary = {}) -> void:
	print("【Boss状态】进入: ", name)

func exit() -> void:
	print("【Boss状态】离开: ", name)

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
