extends Resource
class_name EagleData

## 老鹰数据配置

@export var max_hp: int = 1                  # 生命值
@export var move_speed: float = 300.0         # 目标飞行速度（像素/秒）
@export var contact_damage: int = 1           # 接触玩家伤害
@export var dive_curve_strength: float = 200.0 # 俯冲曲线弯曲度（越大加速越快、弧线越急）
@export var turn_deceleration: float = 100.0  # 掉头减速度（像素/秒²，越大越快停下转身）
@export var death_anim: String = "death"      # 死亡动画名
@export var death_sound: StringName = &"disiwang" # 死亡音效ID
