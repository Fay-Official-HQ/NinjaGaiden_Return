# res://resources/enemy/EnemyData.gd
extends Resource

class_name EnemyData

# 基础属性
@export var max_health: int = 100
@export var move_speed: float = 50.0
@export var chase_speed: float = 80.0

# 战斗属性
@export var attack_damage: int = 20
@export var attack_range: float = 30.0
@export var attack_cooldown: float = 1.0

# AI 属性
@export var detection_range: float = 150.0
@export var patrol_speed: float = 30.0
@export var patrol_pause_time: float = 2.0
