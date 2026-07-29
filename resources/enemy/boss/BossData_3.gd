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
## 与玩家距离判定：近战距离（像素），小于此值停止移动
@export var ai_close_distance: float = 30.0
## 与玩家距离判定：中距离（像素），预留备用
@export var ai_medium_distance: float = 120.0
## 循环状态列表（按顺序轮流执行）
@export var ai_state_cycle: Array[String] = [
	"Boss3RunState",
	"Boss3AttackState",
	"Boss3SwordReadyState",
	"Boss3CrouchState",
	"Boss3JumpState",
	"Boss3GroundNinjutsuState",
	"Boss3AirNinjutsuState",
	"Boss3FallAirState",
]

# ==================== 阶段参数 ====================
## 二阶段血量阈值（HP低于此值切换循环列表）
@export var phase2_hp_threshold: int = 20
## 二阶段循环状态列表（加强版，更多剑术和忍术）
@export var ai_state_cycle_phase2: Array[String] = [
	"Boss3RunState",
	"Boss3AttackState",
	"Boss3SwordReadyState",
	"Boss3CrouchState",
	"Boss3JumpState",
	"Boss3GroundNinjutsuState",
	"Boss3AirNinjutsuState",
	"Boss3FallAirState",
]

# ==================== 下蹲参数 ====================
## 下蹲持续时间（秒），结束后自动接下蹲攻击
@export var crouch_duration: float = 0.5

# ==================== 格挡参数 ====================
## 格挡持续时间（秒）
@export var block_duration: float = 0.5
## 剑术备战持续时间（秒），结束后随机释放剑术
@export var sword_ready_duration: float = 1.5
## 基础格挡概率（满血时，0~1）
@export var block_chance_base: float = 0.3
## 二阶段格挡概率（HP≤阶段2阈值时，0~1）
@export var block_chance_phase2: float = 0.5
## 强化阶段格挡概率（HP≤强化阈值时，0~1）
@export var block_chance_enhanced: float = 0.75
## 强化状态触发血量阈值
@export var enhanced_hp_threshold: int = 10
