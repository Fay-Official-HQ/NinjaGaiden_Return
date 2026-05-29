extends State

func enter():
	player.play_animation("fall")

func physics_update(delta):
	var direction = Input.get_axis("nav_left", "nav_right")
	player.velocity.x = direction * player.walk_speed
	if direction != 0:
		player.set_flip(direction < 0)
	if player.is_on_floor():
		if direction != 0:
			state_machine.change_state(get_node("../Run"))
		else:
			state_machine.change_state(get_node("../Idle"))
