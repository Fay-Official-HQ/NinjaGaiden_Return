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

var jump_buffer_time := 0.12

var jump_buffer_timer := 0.0


func update_input():
	

	move_direction = Input.get_axis(
		"nav_left",
		"nav_right"
	)
	
	if Input.is_action_just_pressed("jump"):

		jump_buffer_timer = jump_buffer_time
		

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
		"finishing_move"
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
	
func update_buffer(delta):

	if jump_buffer_timer > 0:

		jump_buffer_timer -= delta
		
func consume_jump() -> bool:

	if jump_buffer_timer > 0:

		jump_buffer_timer = 0

		return true

	return false
