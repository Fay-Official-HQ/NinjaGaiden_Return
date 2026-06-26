# res://scripts/components/HurtBox.gd
extends Area2D

class_name HurtBox

## 是否为 Boss（影响忍术投射物的伤害逻辑）
@export var is_boss: bool = false

## 同一 HurtBox 多次受击的最小间隔（秒），防止同一帧/短时内多次触发
@export var invincible_time: float = 0.15

## 受到伤害时发出的信号，is_heavy 表示是否为重击（用于触发 Boss 硬直）
signal took_damage(damage: int, is_heavy: bool)

var _last_hit_time: float = -10.0

func _ready() -> void:
	monitoring = false
	monitorable = true

## 普通伤害（普攻、忍术、剑术普通连击、必杀技普通段）
func take_damage(damage: int) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < invincible_time:
		return
	_last_hit_time = now
	took_damage.emit(damage, false)

## 重击伤害（剑术技能、必杀技最后一击）—— 用于触发 Boss 硬直
func take_heavy_damage(damage: int) -> void:
	var now = Time.get_ticks_msec() / 1000.0
	if now - _last_hit_time < invincible_time:
		return
	_last_hit_time = now
	took_damage.emit(damage, true)
