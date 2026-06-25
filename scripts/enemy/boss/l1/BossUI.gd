extends CanvasLayer
class_name BossUI

@onready var hp_bar_bg: Sprite2D = $HpBarBg
@onready var hp_fill: Sprite2D = $HpBarFill

var _max_hp: int = 1
var _bg_top_y: float = 0.0
var _bg_height: float = 0.0

func initialize(boss_data: BossData) -> void:
	_max_hp = boss_data.max_hp
	_bg_top_y = hp_bar_bg.position.y
	_bg_height = hp_bar_bg.texture.get_height()
	visible = false

func update_hp(current: int) -> void:
	var ratio = float(current) / float(_max_hp)
	var fill_height = _bg_height * ratio
	hp_fill.scale.y = ratio
	hp_fill.position.y = _bg_top_y + _bg_height - fill_height

func show_with_animation() -> void:
	visible = true

func hide_with_animation() -> void:
	visible = false
