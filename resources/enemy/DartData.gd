# res://resources/enemy/DartData.gd
# 飞镖投射物数据
extends Resource
class_name DartData

@export var speed: float = 200.0       # 飞行速度（像素/秒）
@export var damage: int = 1            # 对玩家伤害
@export var max_hp: int = 1            # 被玩家攻击可摧毁（1次）

## 发射角度偏移（度），负值=向上偏移，正值=向下偏移
## 设为 -10 ~ -5 度让飞镖略向上飞，玩家可以蹲下躲避
@export var launch_angle_offset: float = 0.0

## 被摧毁时的死亡音效
@export var death_sound: StringName = &"disiwang"
