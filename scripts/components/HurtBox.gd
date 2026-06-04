# res://scripts/components/HurtBox.gd
extends Area2D

class_name HurtBox

## 是否为 Boss（影响忍术投射物的伤害逻辑：Boss 扣3点血，普通小怪秒杀）
@export var is_boss: bool = false

## 受到伤害时发出的信号，交由父节点（如玩家或敌人自身）去实际扣血
signal took_damage(damage: int)

func _ready() -> void:
	monitoring = false
	monitorable = true

## 供 HitBox 调用的公共接口
func take_damage(damage: int) -> void:
	took_damage.emit(damage)
