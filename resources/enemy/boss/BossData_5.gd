extends BossData
class_name BossData_5

# ── 飞行参数（第5章 Boss 在 FlyMark 标记点之间正弦波飞行）──
## 飞行移动速度（像素/秒）
@export var fly_speed: float = 120.0
## 正弦波振幅（像素）
@export var sine_amplitude: float = 30.0
## 正弦波频率（弧度/秒）
@export var sine_frequency: float = 3.0
## 抵达目标点判定距离（像素）
@export var reach_threshold: float = 10.0

# ── 单手发射（shoot）参数 ──
## 蓄力时长（秒），期间播放 shoot 动画并显示 EnergyAnimated
@export var shoot_charge_time: float = 1.0
## 发射的激光数量（上下两方向散射）
@export var laser_count: int = 4
## 激光总散射角（度），向玩家方向上下对称张开
@export var laser_scatter_deg: float = 30.0
## 激光飞行速度（像素/秒）
@export var laser_speed: float = 300.0

# ── 蓄力能量闪烁参数（我需要调试）──
## 闪烁最低透明度（0~1），越小闪烁越明显
@export var flicker_min_alpha: float = 0.1
## 闪烁半周期（秒），越小闪烁越快
@export var flicker_half_period: float = 0.65

# ── 激光弹幕参数（我需要调试）──
## 激光追踪转向率（度/秒），越大弹道修正越快
@export var laser_homing_turn_rate: float = 100.0
## 激光发射后先沿散射方向直线扩散的时长（秒），到期后才开始追踪玩家
@export var laser_homing_delay: float = 0.5
## 激光可承受的伤害次数（被攻击可打掉的耐久）
@export var laser_hp: int = 1
## 激光最大存活时长（秒），超时强制销毁，防止无限飞行造成性能问题
@export var laser_lifetime: float = 5.0

# ── 双手发射（shoot_both）参数（我需要调试）──
## 双手发射蓄力时长（秒）
@export var shoot_both_charge_time: float = 1.0
## 双手发射前先垂直飞到玩家水平线的移动速度（像素/秒）
@export var phoenix_align_speed: float = 150.0
## 到达玩家水平线的判定容差（像素）
@export var phoenix_align_tolerance: float = 5.0
## 双手发射对齐时不允许低于的最低高度（世界 Y 坐标，数值越大越靠下）。
## 若玩家在更低处，Boss 只对齐到该高度，不继续下移（我需要调试）
@export var phoenix_min_align_y: float = 180.0
## 火凤凰横向飞行速度（像素/秒）
@export var phoenix_speed: float = 600.0
## 火凤凰伤害
@export var phoenix_damage: int = 3

# ── 飞踢（kick）参数（我需要调试）──
## 飞踢蓄力时长（秒），期间播放 summon_down 动画
@export var kick_charge_time: float = 0.35
## 飞踢冲刺距离（像素）
@export var kick_distance: float = 150.0
## 飞踢冲刺速度（像素/秒）
@export var kick_speed: float = 350.0
## 注：飞踢对齐玩家水平线的速度/容差/最低高度复用双手发射的 phoenix_* 参数

# ── 覆盖式轰炸（必杀技）参数（我需要调试）──
## Boss 播放 hongzha 召唤动画的时长（秒），播完即可飞行/攻击，不被锁死
@export var bomb_summon_time: float = 3.0
## 导弹生成间隔（秒），越小落弹越密
@export var bomb_spawn_interval: float = 0.3
## 轰炸总持续时间（秒），导弹生成器持续工作到该时长结束
@export var bomb_duration: float = 10.0
## 导弹下落速度（像素/秒）
@export var bomb_missile_speed: float = 400.0
## 导弹爆炸伤害
@export var bomb_missile_damage: int = 3
## 轰炸开始后延迟（秒）才出现恢复补给（先播巫女祝福动画+语音），如 5 秒后出现
@export var bomb_reward_delay: float = 5.0
## 第3次轰炸额外奖励：开始后延迟（秒）才出现 ItemGated3（如 3 秒后）
@export var bomb3_reward3_delay: float = 3.0
## 第3次轰炸开启的士兵波次：每波空降兵随机数量上限（实际 1~N 个，hongzha 范围内随机空降）
@export var bomb3_paratrooper_count: int = 3
## 士兵波次间隔（秒）：一波全部消失后等待该时长再出下一波
@export var bomb3_soldier_wave_gap: float = 3.0
## 注：导弹生成范围 = 关卡 hongzha 节点下 Marker2D1 与 Marker2D2 两坐标框定的矩形（x/y 均随机）

# ── 受击闪白参数（我需要调试）──
## 闪白峰值亮度（越大越白越刺眼）
@export var hurt_flash_strength: float = 4.0
## 闪白过渡中间亮度
@export var hurt_flash_mid: float = 4.0
## 闪白衰减到正常色的时长（秒）
@export var hurt_flash_decay: float = 0.15

# ── 战斗区域：Boss 飞行范围限制（我需要调试）──
## 战斗区域左边界（世界 X 坐标）
@export var battle_area_left: float = 520.0
## 战斗区域右边界（世界 X 坐标）
@export var battle_area_right: float = 1000.0
## 战斗区域上边界（世界 Y 坐标）
@export var battle_area_top: float = 0.0
## 战斗区域下边界（世界 Y 坐标）
@export var battle_area_bottom: float = 180.0

# ── AI 决策参数（我需要调试）──
## 距离分区：近距阈值（像素），低于此视为玩家贴身
@export var ai_dist_close: float = 120.0
## 距离分区：远距阈值（像素），大于等于此视为玩家远离
@export var ai_dist_far: float = 250.0
## 垂直对齐判定阈值（像素）：dy 小于此值视为 Boss 已与玩家同水平线
@export var ai_align_threshold: float = 30.0
## 全局攻击冷却（秒）：选完一次攻击后的最小间隔，期间 Boss 只飞行
@export var ai_global_cooldown: float = 1.2

## 激光散射评分：基础分
@export var ai_laser_base: float = 30.0
## 激光散射评分：近距加成
@export var ai_laser_close_bonus: float = 20.0
## 激光散射评分：中距加成（激光主场）
@export var ai_laser_mid_bonus: float = 40.0
## 激光散射评分：远距加成
@export var ai_laser_far_bonus: float = 15.0
## 激光散射评分：玩家在下方（dy 大于对齐阈值）时加成
@export var ai_laser_vertical_bonus: float = 20.0
## 激光技能冷却（秒）
@export var ai_cooldown_laser: float = 2.0

## 火凤凰评分：远距加成（凤凰主场）
@export var ai_phoenix_far_bonus: float = 60.0
## 火凤凰评分：中距加成
@export var ai_phoenix_mid_bonus: float = 35.0
## 火凤凰评分：近距基本不用
@export var ai_phoenix_close_penalty: float = 5.0
## 火凤凰评分：垂直已对齐时加成
@export var ai_phoenix_align_bonus: float = 25.0
## 火凤凰评分：垂直偏差大时扣分
@export var ai_phoenix_misalign_penalty: float = 10.0
## 火凤凰评分：玩家移动中扣分（横向直线易被走位躲）
@export var ai_phoenix_move_penalty: float = 15.0
## 火凤凰技能冷却（秒）
@export var ai_cooldown_phoenix: float = 3.0

## 飞踢评分：近距加成（飞踢主场）
@export var ai_kick_close_bonus: float = 55.0
## 飞踢评分：中距加成
@export var ai_kick_mid_bonus: float = 30.0
## 飞踢评分：远距加成（太远够不到）
@export var ai_kick_far_bonus: float = 0.0
## 飞踢评分：垂直已对齐时加成
@export var ai_kick_align_bonus: float = 25.0
## 飞踢评分：垂直偏差大时扣分
@export var ai_kick_misalign_penalty: float = 20.0
## 飞踢评分：玩家移动中扣分
@export var ai_kick_move_penalty: float = 10.0
## 飞踢技能冷却（秒）
@export var ai_cooldown_kick: float = 1.5

## 二阶段血量阈值（0~1 比例），低于则进入狂暴二阶段
@export var ai_phase2_hp_ratio: float = 0.5
## 二阶段攻击评分激进倍率（所有攻击分数放大）
@export var ai_phase2_aggression_multiplier: float = 1.3
## 二阶段全局冷却缩减比例（0~1）
@export var ai_phase2_cooldown_reduce: float = 0.7

## 轰炸（必杀技）固定血线触发：血量依次低于这些值时各触发一次，全程最多 3 次
## （不参与评分，优先级最高）
@export var ai_bomb_trigger_hp: Array[int] = [25, 18, 10]
