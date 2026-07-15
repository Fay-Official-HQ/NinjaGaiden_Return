extends Node2D

var _selected_index := 0
var _transitioning := false

const ENTRY_GAP := 18

const CHAPTERS := [
	{ chapter = 1, path = "res://scenes/levels/Level_1.tscn",      name = "第一章 甦る忍者" },
	{ chapter = 2, path = "res://scenes/levels/l2/Level_2-1.tscn",  name = "第二章 闇の始まり" },
	{ chapter = 3, path = "", name = "第三章 ???（未開放）" },
	{ chapter = 4, path = "", name = "第四章 ???（未開放）" },
	{ chapter = 5, path = "", name = "第五章 ???（未開放）" },
	{ chapter = 6, path = "", name = "第六章 ???（未開放）" },
	{ chapter = 7, path = "", name = "第七章 ???（未開放）" },
	{ chapter = 8, path = "", name = "第八章 ???（未開放）" },
	{ chapter = 9, path = "", name = "第九章 ???（未開放）" },
]

@onready var menu: Node2D = $Menu
@onready var cursor: Sprite2D = $Menu/Cursor
@onready var menu_click_sfx: AudioStreamPlayer = $MenuClick

@onready var chapter_nodes: Array[Node2D] = [
	$Menu/chapter_1,
	$Menu/chapter_2,
	$Menu/chapter_3,
	$Menu/chapter_4,
	$Menu/chapter_5,
	$Menu/chapter_6,
	$Menu/chapter_7,
	$Menu/chapter_8,
	$Menu/chapter_9,
]


func _ready() -> void:
	UIManager.visible = false
	_gray_unlocked()


func _gray_unlocked() -> void:
	for i in CHAPTERS.size():
		if CHAPTERS[i].path == "":
			for child in chapter_nodes[i].get_children():
				if child is Label:
					child.modulate = Color(0.35, 0.35, 0.35)


func _input(event: InputEvent) -> void:
	if event.is_echo() or _transitioning:
		return

	if event.is_action_pressed("nav_up"):
		_move_cursor(-1)
	elif event.is_action_pressed("nav_down"):
		_move_cursor(1)
	elif event.is_action_pressed("pass"):
		_confirm_selection()
	elif event is InputEventKey and event.pressed and not event.echo \
			and event.keycode == KEY_ESCAPE:
		_go_back()


func _move_cursor(dir: int) -> void:
	var prev = _selected_index
	_selected_index = clampi(_selected_index + dir, 0, CHAPTERS.size() - 1)
	if _selected_index != prev:
		cursor.position.y += dir * ENTRY_GAP


func _confirm_selection() -> void:
	var chapter = CHAPTERS[_selected_index]
	if chapter.path == "":
		return

	_transitioning = true
	menu_click_sfx.play()
	var tween = create_tween()
	tween.tween_property(menu, "modulate:a", 0.0, 1.0)
	await tween.finished

	Cutscene.target_chapter = chapter.chapter
	get_tree().change_scene_to_file("res://scenes/ui/Cutscene.tscn")


func _go_back() -> void:
	_transitioning = true
	get_tree().change_scene_to_file("res://scenes/ui/TitleScreen.tscn")
