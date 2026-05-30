extends Node

class_name InputComponent

var move_direction: float = 0.0

var up_pressed: bool = false
var down_pressed: bool = false

var jump_pressed: bool = false
var attack_pressed: bool = false
var dash_pressed: bool = false

var ninjutsu_pressed: bool = false
var switch_ninjutsu_pressed: bool = false
var special_move_pressed: bool = false


func update_input():

	move_direction = Input.get_axis(
		"nav_left",
		"nav_right"
	)

	up_pressed = Input.is_action_pressed(
		"nav_up"
	)

	down_pressed = Input.is_action_pressed(
		"nav_down"
	)

	jump_pressed = Input.is_action_just_pressed(
		"jump"
	)

	attack_pressed = Input.is_action_just_pressed(
		"attack"
	)

	dash_pressed = Input.is_action_just_pressed(
		"dash"
	)

	ninjutsu_pressed = Input.is_action_just_pressed(
		"ninjutsu"
	)

	switch_ninjutsu_pressed = Input.is_action_just_pressed(
		"switch_ninjutsu"
	)

	special_move_pressed = Input.is_action_just_pressed(
		"special_move"
	)
