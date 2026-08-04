extends BossData
class_name BossData_3

# ============================================================
# 文件：resources/enemy/boss/BossData_3.gd
# 作用：第三关 BOSS 假隼龙（Fake Ryu）的专属数据资源
# 说明：所有数值均可在编辑器 Inspector 中调整，方便快速调试
# ============================================================

# ==================== 基础移动参数 ====================
## 奔跑速度（像素/秒）
@export var run_speed: float = 120.0
## 跳跃初速度（像素/秒，负Y方向，匹配玩家 -260）
@export var jump_velocity: float = -260.0
## 空中水平移动速度（像素/秒，留接口备用，当前空中状态不使用）
@export var air_speed: float = 120.0
## 重力加速度（像素/秒²）
@export var gravity: float = 700.0

# ==================== 攻击位移参数 ====================
## 普通攻击突进距离（像素，0=不突进）
@export var attack_lunge_distance: float = 0.0
## 剑冲刺速度（像素/秒）
@export var sword_dash_speed: float = 250.0
## 剑冲刺距离（像素，耗尽后进入恢复阶段）
@export var sword_dash_distance: float = 100.0
## 剑冲刺恢复时间（秒，冲刺后硬直）
@export var sword_dash_recover_duration: float = 0.2
## 剑旋转突进距离（像素）
@export var sword_spin_distance: float = 80.0
## 剑旋转速度倍率（run_speed * 此值 = 旋转突进速度）
@export var sword_spin_speed_multiplier: float = 1.5

# ==================== 剑术上挑参数 ====================
## 上挑跳跃速度倍率（jump_velocity * 此值）
@export var uppercut_jump_multiplier: float = 1.2
## 上挑水平速度倍率（run_speed * 此值）
@export var uppercut_speed_multiplier: float = 1.2
## 上挑前突进距离（像素，耗尽后清空水平速度）
@export var uppercut_dash_distance: float = 50.0

# ==================== 飞行参数 ====================
## 空中失衡直线飞行速度（像素/秒，FallAirState）
@export var fall_air_fly_speed: float = 400.0
## 飞行到顶部标记点速度（像素/秒，FlightToTopState）
@export var flight_to_top_speed: float = 400.0
## 下劈速度（像素/秒，SwordDownslashState 朝玩家方向直线下劈）
@export var sword_downslash_speed: float = 500.0
## 飞行到顶后悬浮时间（秒，FlightToTopState 到达目标后停顿再下劈）
@export var flight_hover_duration: float = 0.1

# ==================== 投掷参数 ====================
## 普通飞镖飞行速度（像素/秒）
@export var throw_dart_speed: float = 350.0
## 爆炸飞镖飞行速度（像素/秒）
@export var throw_fire_dart_speed: float = 350.0
## 投掷触发最小距离（像素）
@export var throw_min_range: float = 80.0
## 投掷触发最大距离（像素）
@export var throw_max_range: float = 350.0
## 普通飞镖音效
@export var throw_dart_sound: StringName = &"rengbiao"
## 爆炸飞镖音效
@export var throw_fire_dart_sound: StringName = &"shibingfashe"

# ==================== 受伤 / 击退参数 ====================
## 受重击硬直时间（秒，继承自 BossData，默认 0.8）
## 在 BossData.gd 中定义，这里不重新声明，可在 Inspector 调整
## 受重击后击退距离（像素，继承自 BossData，默认 15）

# ==================== 出场参数 ====================
## 出场时机身淡出时间（秒）
@export var appear_fade_out_time: float = 1.0
## 出场时隐藏停留时间（秒）
@export var appear_hidden_time: float = 2.0
## 出场时淡入显现时间（秒）
@export var appear_fade_in_time: float = 1.0

# ==================== 死亡参数 ====================
## 死亡音效后等待时间（秒），然后隐藏 BOSS
@export var death_sound_delay: float = 2.0
## 隐藏 BOSS 后等待时间（秒），然后重置玩家
@export var death_hide_delay: float = 1.0
## 场景淡入淡出过渡时间（秒）
@export var death_fade_duration: float = 2.0
## 场景过渡后删除 BOSS 节点前的额外等待（秒）
@export var death_cleanup_delay: float = 0.5

# ==================== 忍术生成位置偏移 ====================
## 忍术弹体生成 X 偏移（像素，朝向方向 * 此值）
@export var ninjutsu_spawn_offset_x: float = 20.0
## 火术（renshuhuoyan）生成 Y 偏移（像素，相对 BOSS 中心）
@export var ninjutsu_fire_spawn_y: float = -8.0
## 火球术（renshuhuoqiu）生成 Y 偏移（像素）
@export var ninjutsu_fireball_spawn_y: float = 8.0

# ==================== AI 决策参数 ====================
## AI 决策间隔（秒），在 IdleState 中每此间隔选一次动作
@export var ai_decision_interval: float = 0.5
## AI 反应延迟（秒），模拟真人延迟响应
@export var ai_reaction_delay: float = 0.08
## 进攻策略触发距离（像素），小于此值且玩家未攻击时进入进攻
@export var ai_offensive_range: float = 150.0
## 防御策略触发距离（像素），小于此值且玩家攻击时进入防御
@export var ai_defensive_range: float = 120.0
## 远程策略触发距离（像素），大于此值或残血时进入远程
@export var ai_ranged_range: float = 250.0
## 逃避策略触发血量比例（0~1），HP低于此比例时优先逃避
@export var ai_evasive_hp_ratio: float = 0.3

# ==================== 下蹲参数 ====================
## 下蹲持续时间（秒），结束后自动接下蹲攻击
@export var crouch_duration: float = 0.5

# ==================== 格挡参数 ====================
## 格挡持续时间（秒）
@export var block_duration: float = 0.5
## 剑术备战持续时间（秒），结束后随机释放剑术
@export var sword_ready_duration: float = 1.5
## 基础格挡概率（满血时，0~1）
@export var block_chance_base: float = 0.15
## 二阶段格挡概率（HP≤阶段2阈值时，0~1）
@export var block_chance_phase2: float = 0.25
## 强化阶段格挡概率（HP≤强化阈值时，0~1）
@export var block_chance_enhanced: float = 0.35
## 强化状态触发血量阈值
@export var enhanced_hp_threshold: int = 10
## 二阶段血量阈值
@export var phase2_hp_threshold: int = 20

# ==================== 必杀技参数（数据驱动） ====================
## 消失淡出时间（秒）
@export var special_fade_out_time: float = 0.3
## 隐身停留时间（秒）
@export var special_hidden_time: float = 1.0
## 显现充能时间（秒）
@export var special_appear_time: float = 0.3
## 充能完成后等待时间（秒）
@export var special_charge_wait: float = 0.5
## sp1 前冲速度（像素/秒）
@export var sp1_dash_speed: float = 400.0
## sp1 最后一帧维持时间（秒）
@export var sp1_hold_time: float = 0.1
## sp2 显现时间（秒）
@export var sp2_appear_time: float = 0.1
## sp2 下劈速度（像素/秒）
@export var sp2_dive_speed: float = 500.0
## sp3 落地等待时间（秒）
@export var sp3_land_wait: float = 0.2
## sp3 旋转距离（像素）
@export var sp3_spin_distance: float = 60.0
## sp3 最后一帧维持时间（秒）
@export var sp3_hold_time: float = 0.1
## sp4 显现距离（像素，相对玩家）
@export var sp4_appear_distance: float = 80.0
## sp4 显现时间（秒）
@export var sp4_appear_time: float = 0.2
## sp4 挥刀突进距离（像素）
@export var sp4_slash_distance: float = 60.0
## sp4 挥刀速度（像素/秒）
@export var sp4_slash_speed: float = 250.0
## sp4 最后一帧维持时间（秒）
@export var sp4_hold_time: float = 0.1
## sp5 显现距离（像素，相对玩家）
@export var sp5_appear_distance: float = 100.0
## sp5 显现时间（秒）
@export var sp5_appear_time: float = 0.1
## sp5 旋转距离（像素）
@export var sp5_spin_distance: float = 80.0
## sp6 升龙突进距离（像素）
@export var sp6_uppercut_distance: float = 50.0
## sp7 空中悬浮时间（秒）
@export var sp7_float_time: float = 0.3
## sp7 下劈速度（像素/秒）
@export var sp7_dive_speed: float = 500.0
## sp7 落地后维持时间（秒）
@export var sp7_land_hold: float = 0.1
