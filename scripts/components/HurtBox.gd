# res://scripts/components/HurtBox.gd
extends Area2D

class_name HurtBox

## 受到伤害时发出的信号，交由父节点（如玩家或敌人自身）去实际扣血
signal took_damage(damage: int)

func _ready() -> void:
	monitoring = false
	monitorable = true

## 供 HitBox 调用的公共接口
func take_damage(damage: int) -> void:
	took_damage.emit(damage)
