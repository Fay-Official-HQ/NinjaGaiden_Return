# res://scripts/components/PlayerHitBox.gd
extends Area2D

class_name PlayerHitBox

@export var damage: int = 1

func _ready() -> void:
	monitoring = false   # 默认关闭，攻击时才开
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(damage)
		# 打中后立刻关闭，防止一刀多判
		set_deferred("monitoring", false)
