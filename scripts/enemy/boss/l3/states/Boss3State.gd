# res://scripts/enemy/boss/l3/states/Boss3State.gd
extends Node
class_name Boss3State

var boss: Boss3
var state_machine: Boss3StateMachine

func enter(_msg: Dictionary = {}) -> void:
	print("【假隼龙状态】进入: ", name)

func exit() -> void:
	print("【假隼龙状态】离开: ", name)

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

## 面向玩家
func _face_player() -> void:
	if not boss.player_ref:
		return
	var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
	boss.set_facing_direction(dir)

## 检测是否在地面上
func _is_on_ground() -> bool:
	return boss.is_on_floor()

## 根据动画是否播放完毕切换回Idle
func _return_to_idle_when_animation_finished() -> void:
	if not boss.animated_sprite.is_playing():
		state_machine.change_state_by_name("Boss3IdleState")
