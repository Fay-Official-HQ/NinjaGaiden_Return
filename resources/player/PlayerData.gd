# res://resources/player/PlayerData.gd
extends Resource

class_name PlayerData

@export var walk_speed: float = 100.0
@export var jump_force: float = 260.0
@export var gravity: float = 700.0
@export var max_hp: int = 16
@export var initial_hp: int = 16
@export var attack_power: int = 1
@export var max_tp: int = 16
@export var initial_tp: int = 16

# 【新增配置项】空中失衡状态下的后退速度修正系数（1.0为常速，0.7为原速的70%）
@export var imbalance_speed_factor: float = 0.7
@export var max_mp: int = 16
@export var initial_mp: int = 16
