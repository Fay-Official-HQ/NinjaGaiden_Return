extends State

func enter():
	player.velocity.y = player.jump_speed
	player.play_animation("jump")

func physics_update(delta):
	var direction = Input.get_axis("nav_left", "nav_right")
	player.velocity.x = direction * player.walk_speed
	if direction != 0:
		player.set_flip(direction < 0)
	if player.velocity.y > 0:
		state_machine.change_state(get_node("../Fall"))
