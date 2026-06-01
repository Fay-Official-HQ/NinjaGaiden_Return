# res://scripts/components/HitBox.gd
extends Area2D

class_name HitBox

## 基础伤害值，可以在检查器面板直接配置
@export var damage: int = 1

func _ready() -> void:
	# 规范约束：HitBox 只负责“主动打人”，不需要被别人探测
	monitoring = true
	monitorable = false
	
	# 严禁编辑器连线，使用代码显式连接信号[cite: 5]
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	# 类型安全检查：如果碰到的区域是合法的 HurtBox，则触发伤害传递
	if area is HurtBox:
		area.take_damage(damage)
