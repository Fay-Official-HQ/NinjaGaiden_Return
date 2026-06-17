extends Area2D

class_name DeathZone

#自定义类型，设置超出游戏区域受到99伤害
@export var damage: int = 99

func _ready() -> void:
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(damage)
