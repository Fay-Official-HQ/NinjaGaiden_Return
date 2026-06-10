# res://resources/enemy/BaseEnemyData.gd
# 小怪通用数据基类（所有小怪数据资源的父类）
extends Resource

class_name BaseEnemyData

@export var max_hp: int = 1
@export var move_speed: float = 20.0
@export var contact_damage: int = 1
@export var damage: int = 1
@export var death_anim: String = "death"
@export var death_sound: StringName = &"disiwang"
