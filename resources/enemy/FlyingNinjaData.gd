extends Resource
class_name FlyingNinjaData

## ── 飞天忍者数据配置 ──
## 调试建议：
##   1. 如果蹦得太低不够进入视野 → 调大 rise_speed（如 500）或调小 rise_deceleration（如 400）
##   2. 如果蹦得太高超出屏幕 → 调小 rise_speed 或调大 rise_deceleration
##   3. 如果坠落太慢/太快 → 调 fall_speed
##   4. 如果飞镖飞得太慢让玩家容易躲 → 调大 dart_speed（如 300）

# ──── 攻击类型 ────
enum AttackType { DART, FIRE }
@export var attack_type: AttackType = AttackType.DART

# ──── 基础属性 ────
@export var max_hp: int = 1                    # 生命值（玩家砍1刀死）

# ──── 上升物理参数（抛石头运动模型） ────
## 初始向上爆发速度（像素/秒）
## 越大蹦得越高越快，建议范围：200 ~ 500
@export var rise_speed: float = 400.0

## 上升减速度（像素/秒²），相当于"向上飞的重力"
## 越大上升弧线越短、越早到达最高点，建议范围：400 ~ 800
@export var rise_deceleration: float = 600.0

# ──── 坠落参数 ────
## 下坠最大速度（像素/秒）
## 越大坠落越快离开屏幕，建议范围：200 ~ 500
@export var fall_speed: float = 400.0

# ──── 攻击参数 ────
## 飞镖飞行速度（像素/秒）
## 建议范围：150 ~ 300（200左右玩家需要跳跃躲避比较合适）
@export var dart_speed: float = 200.0

## 火焰飞行速度（像素/秒）
## 建议范围：150 ~ 350
@export var fire_speed: float = 400.0

## 火焰忍者下落多久后释放火焰（秒）
## 给玩家反应时间来击杀，建议范围：0.2 ~ 0.8
@export var fire_attack_delay: float = 0.4

## 身体接触对玩家的伤害
@export var contact_damage: int = 1

# ──── 音效配置 ────
## 出现（上升瞬间）的音效ID
@export var appear_sound: StringName = &"jianxuanzhuan"

## 飞镖攻击音效ID
@export var attack_sound_dart: StringName = &"rengbiao"

## 火焰攻击音效ID
@export var attack_sound_fire: StringName = &"jianqianchong"

## 飞镖忍者的死亡音效ID
@export var death_sound_dart: StringName = &"disiwang"

## 火焰忍者的死亡音效ID
@export var death_sound_fire: StringName = &"disiwang2"

# ──── 死亡相关 ────
@export var death_anim: String = "death"       # 死亡动画名（在 SpriteFrames 中定义）
