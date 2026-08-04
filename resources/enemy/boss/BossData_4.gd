extends BossData
class_name BossData_4

# ============================================================
# 文件：resources/enemy/boss/BossData_4.gd
# 作用：第四关 BOSS（建筑类，骷髅头 + 女人身体）的专属数据资源
# 说明：所有数值均可在编辑器 Inspector 中调整，方便快速调试
# ============================================================

# ==================== 攻击循环参数 ====================
## 攻击间隔（秒）：每轮攻击结束后等待此时间再开始下一轮
@export var attack_interval: float = 3.0
## 每轮生成的鬼火数量（对应 Marker2D ~ Marker2D4）
@export var fire_count: int = 4
## 等待鬼火全部聚集的最长时间（秒）：超过后按已聚集数量结算，
## 必须 > fire_idle_time(2s) + 最远鬼火飞到 Marker2D5 的时间（最远约 291px / fire_speed 80 ≈ 3.6s）
## ≈ 5.6s，默认 8s 保证 4 团都能在窗口内到达
@export var collect_wait_time: float = 8.0
## 鬼火飞向聚集点的速度（像素/秒）
@export var fire_speed: float = 80.0
## 鬼火出现后的原地待机时间（秒），需求：火焰产生后先静止待机 2 秒再飞向聚集点
@export var fire_idle_time: float = 2.0
## 每聚集 1 团鬼火，能量波伤害增加的点数（需求：每收集 1 个鬼火伤害 2，4 个全部收集伤害 8）
@export var per_fire_damage: int = 2
## 能量动画（EnergyAnimated）闪烁时长（秒），闪烁结束后发射能量波（默认 2 秒）
@export var energy_flicker_duration: float = 2.0

# ==================== 能量波（EnergyFire）参数 ====================
## 能量波飞行速度（像素/秒）
@export var energy_wave_speed: float = 300.0
## 能量波伤害 = 收集鬼火数 * per_fire_damage（收集 0 个不发射能量波）
## 能量动画（EnergyAnimated）闪烁参数
## 闪烁最低透明度（0~1，越小闪得越暗）
@export var flicker_min_alpha: float = 0.5
## 闪烁半周期时长（秒）：一次"由亮到暗"或"由暗到亮"的用时，越小闪得越快
@export var flicker_half_period: float = 0.055

# ==================== 音效参数 ====================
## 每波火焰生成时播放的音效（与普通鬼火生成器一致）
@export var spawn_sound: StringName = &"guihuo"
## 蓄力能量期间（EnergyAnimated 闪烁时）播放的音效，与玩家蓄力音效一致
@export var charge_sound: StringName = &"xuli"

# ==================== 小怪（hopper_monster）召唤参数 ====================
## 每间隔多少秒在 Marker2D6 生成 1 个 hopper_monster（默认 8 秒）
@export var spawn_minion_interval: float = 8.0
## 小怪生成位置的随机左右偏移范围（像素，±此值内随机）
@export var minion_spawn_offset: float = 20.0

# ==================== 死亡参数 ====================
## 死亡音效
@export var death_sound: StringName = &"disiwang"
## 死亡后 BOSS 显隐间隔（秒），详情见 BossData 基类
## （继承自 BossData：death_anim_duration / defeat_next_scene 等可在此 Inspector 调整）
