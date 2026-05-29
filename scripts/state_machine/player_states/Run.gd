extends State

func enter():
	player.play_animation("run")
	var direction = 1 if player.facing_right else -1
	if player.velocity.x != 0:
		direction = sign(player.velocity.x)
	player.set_flip(direction < 0)

func physics_update(delta):
	if Input.is_action_just_pressed("jump"):
		state_machine.change_state(get_node("../Jump"))
		return
	if not player.is_on_floor():
		state_machine.change_state(get_node("../Fall"))
		return
	var direction = Input.get_axis("nav_left", "nav_right")
	if direction == 0:
		state_machine.change_state(get_node("../Idle"))
	else:
		player.velocity.x = direction * player.walk_speed
		player.set_flip(direction < 0)
