extends BossData
class_name BossData_2

## 摄像机锚点偏移（相对于摄像机的位置）
@export var camera_offset_x: float = 300.0
## 摄像机锚点垂直偏移
@export var camera_offset_y: float = 0.0
## 尖刺必杀技触发血量阈值（HP低于此值时自动触发）
@export var spine_hp_threshold: int = 21

# ==================== AI 决策参数 ====================
## 攻击最小间隔（秒），所有攻击共享此冷却
@export var ai_global_cooldown: float = 1.5
## 尖刺必杀技独立冷却（秒），首次触发后开始计时
@export var ai_spine_cooldown: float = 10.0
## 连续重复惩罚分数（与上次相同的攻击扣此分数）
@export var ai_repeat_penalty: float = 50.0
## 二阶段（HP<16）冲刺类攻击得分倍率
@export var ai_phase2_aggression_bonus: float = 1.2
## 三阶段（HP<10）全局冷却缩短比例
@export var ai_phase3_cooldown_reduce: float = 0.7
