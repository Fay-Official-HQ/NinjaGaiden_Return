extends CanvasLayer
class_name BossUI

@onready var hp_bar: TextureProgressBar = $BossHPBar
@onready var name_label: Label = $BossNameLabel

func initialize(boss_data: BossData) -> void:
	name_label.text = boss_data.boss_name
	hp_bar.max_value = boss_data.max_hp
	hp_bar.value = boss_data.max_hp
	visible = false

func update_hp(current: int) -> void:
	hp_bar.value = current

func show_with_animation() -> void:
	visible = true

func hide_with_animation() -> void:
	visible = false
