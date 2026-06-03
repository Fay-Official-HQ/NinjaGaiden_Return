# res://scripts/components/SwordHitBox.gd
extends Area2D

class_name SwordHitBox

#剑术框的伤害设定为3
@export var damage: int = 2

func _ready() -> void:
	monitoring = false   # 默认关闭，攻击时才开
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(_area: Area2D) -> void:
	pass
