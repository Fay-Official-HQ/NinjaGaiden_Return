extends BaseEnemyData
class_name SoldierData

## 士兵数据配置

## 蓄力时长（秒），检测到玩家后身体变红蓄力，结束后发射激光
@export var charge_duration: float = 1.0

## 射击冷却时间（秒），每次发射后的冷却
@export var attack_cooldown: float = 1.0

## 激光飞行速度（像素/秒），极快
@export var laser_speed: float = 800.0

## 蓄力音效ID
@export var charge_sound: StringName = &"shibingxuli"
## 发射音效ID
@export var shoot_sound: StringName = &"shibingfashe"
