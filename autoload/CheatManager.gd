extends Node

var god_mode: bool = false
signal god_mode_changed(enabled: bool)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F1:
			god_mode = not god_mode
			god_mode_changed.emit(god_mode)
			print("【作弊模式】", "开启" if god_mode else "关闭")
			get_viewport().set_input_as_handled()
			if god_mode:
				UIManager.show_message("超忍模式 ON", 3.0)
			else:
				UIManager.show_message("超忍模式 OFF", 3.0)
