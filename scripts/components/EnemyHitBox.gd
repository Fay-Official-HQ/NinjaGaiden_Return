# res://scripts/components/EnemyHitBox.gd
extends Area2D

class_name EnemyHitBox

@export var damage: int = 1

func _ready() -> void:
	monitoring = true    # 始终开启，检测玩家
	monitorable = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(damage)
		# 不自动关闭，敌人攻击框一直存在，伤害间隔由 HurtBox 的冷却控制
