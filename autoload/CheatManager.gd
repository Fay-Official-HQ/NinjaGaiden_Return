extends Node

## 发布开关：正式版改为 false 即可完全禁用作弊
const ENABLED := true

var god_mode: bool = false
signal god_mode_changed(enabled: bool)


func _ready() -> void:
	if not ENABLED:
		god_mode = false
		set_process_unhandled_input(false)


func _unhandled_input(event: InputEvent) -> void:
	if not ENABLED:
		return
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
