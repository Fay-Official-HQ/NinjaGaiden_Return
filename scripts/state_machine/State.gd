extends Node
class_name State

var player: CharacterBody2D
var state_machine: StateMachine

func enter(): pass
func exit(): pass
func update(_delta): pass
func physics_update(_delta): pass
func handle_input(_event): pass
