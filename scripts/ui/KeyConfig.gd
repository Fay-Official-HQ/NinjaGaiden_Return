extends Node2D

const CURSOR_BASE_Y := 64.0
const ENTRY_GAP := 15.0
const CONFIG_PATH := "user://keybindings.cfg"

var _key_items := [
	{ action = "nav_up",          name = "上",           label = null },
	{ action = "nav_down",        name = "下",           label = null },
	{ action = "nav_left",        name = "左",           label = null },
	{ action = "nav_right",       name = "右",           label = null },
	{ action = "attack",          name = "攻擊",         label = null },
	{ action = "jump",            name = "跳躍",         label = null },
	{ action = "block",           name = "架刀",         label = null },
	{ action = "ninjutsu",        name = "施放忍術",     label = null },
	{ action = "switch_ninjutsu", name = "切換忍術",     label = null },
	{ action = "exterminate",     name = "滅殺",         label = null },
	{ action = "finishing_move",  name = "真龍閃華",     label = null },
	{ action = "pass",            name = "暫停",         label = null },
]

var _selected_index := 0
var _transitioning := false
var _waiting_for_key := false
var _prev_color: Color = Color.WHITE

@onready var menu: Node2D = $Menu
@onready var cursor: Sprite2D = $Menu/Cursor
@onready var menu_click_sfx: AudioStreamPlayer = $MenuClick
@onready var _msg1: Label = $Menu/MenuBackground/msg1
@onready var _msg2: Label = $Menu/MenuBackground/msg2


func _ready() -> void:
	UIManager.visible = false
	_load_config()
	for i in _key_items.size():
		var path = "Menu/Key%d/Label2" % (i + 1)
		if has_node(path):
			_key_items[i].label = get_node(path)
	_update_key_display()
	_update_hint_text()


func _update_key_display() -> void:
	for item in _key_items:
		var text = _get_key_display_text(item.action)
		item.label.text = text


func _get_key_display_text(action: String) -> String:
	var events = InputMap.action_get_events(action)
	for e in events:
		if e is InputEventKey:
			return OS.get_keycode_string(e.physical_keycode)
	return ""


func _input(event: InputEvent) -> void:
	if event.is_echo() or _transitioning:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _waiting_for_key:
			_cancel_waiting()
		else:
			_go_back()
		return

	if _waiting_for_key:
		if event is InputEventKey and event.pressed:
			_assign_key(event)
		return

	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_SPACE:
		_start_waiting()

	if event.is_action_pressed("nav_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("nav_down"):
		_move_cursor(1)


func _move_cursor(dir: int) -> void:
	var prev = _selected_index
	_selected_index = clampi(_selected_index + dir, 0, _key_items.size() - 1)
	if _selected_index != prev:
		_update_cursor_position()


func _update_cursor_position() -> void:
	cursor.position.y = CURSOR_BASE_Y + _selected_index * ENTRY_GAP


func _start_waiting() -> void:
	_waiting_for_key = true
	var item = _key_items[_selected_index]
	_prev_color = item.label.modulate
	item.label.text = "?"
	item.label.modulate = Color(1, 1, 0)


func _cancel_waiting() -> void:
	_waiting_for_key = false
	var item = _key_items[_selected_index]
	item.label.text = _get_key_display_text(item.action)
	item.label.modulate = _prev_color


func _assign_key(event: InputEventKey) -> void:
	_waiting_for_key = false

	var item = _key_items[_selected_index]
	var action_name = item.action

	InputMap.action_erase_events(action_name)
	InputMap.action_add_event(action_name, event)

	item.label.text = OS.get_keycode_string(event.physical_keycode)
	item.label.modulate = _prev_color

	menu_click_sfx.play()
	_save_config()
	_update_hint_text()


func _save_config() -> void:
	var config = ConfigFile.new()
	for item in _key_items:
		var events = InputMap.action_get_events(item.action)
		if events.size() > 0:
			var e = events[0]
			config.set_value("bindings", item.action, e.physical_keycode)
	config.save(CONFIG_PATH)


func _load_config() -> void:
	var config = ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return
	for action in config.get_section_keys("bindings"):
		var keycode = config.get_value("bindings", action) as int
		var event = InputEventKey.new()
		event.physical_keycode = keycode
		InputMap.action_erase_events(action)
		InputMap.action_add_event(action, event)


func _update_hint_text() -> void:
	var up = _get_key_display_text("nav_up")
	var down = _get_key_display_text("nav_down")
	_msg1.text = "%s/%s：上下移動" % [up, down]
	_msg2.text = "SPACE：確認"


func _go_back() -> void:
	if _transitioning:
		return
	_transitioning = true
	_save_config()
	var tween = create_tween()
	tween.tween_property(menu, "modulate:a", 0.0, 1.0)
	await tween.finished
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
