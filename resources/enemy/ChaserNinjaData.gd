# res://resources/enemy/ChaserNinjaData.gd
# 追击拳手忍者（ChaserNinja）专属数据
# ChaserNinja 会追击玩家，遇到断崖或墙壁时跳跃，追踪玩家 Y 轴跳跃
extends BaseEnemyData
class_name ChaserNinjaData

## 追击速度（像素/秒）
@export var chase_speed: float = 200.0

## 跳跃力（velocity.y = 负值=向上跳），建议范围 -200 ~ -300
@export var jump_force: float = -350.0

## 跳跃冷却（秒），防止连跳
@export var jump_cooldown: float = 0.3

## 玩家跳跃追踪阈值：当 player.velocity.y < 此值时触发追踪跳跃
## 默认 -10 表示玩家正在上升（刚起跳）
@export var player_jump_threshold: float = -10.0
