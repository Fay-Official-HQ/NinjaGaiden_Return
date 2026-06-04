# ============================================================
# 棱刃忍术 - 上下弹动穿透敌人
# 使用弹簧振子模型，刀刃根据运动方向自动翻转（远离时朝外，返回时朝内）
# ============================================================
extends Area2D
class_name EdgeBlade

# ---------- 导出参数（可在编辑器中调整） ----------

## 初始运动方向（Vector2.UP 向上，Vector2.DOWN 向下）
## 原图需保证刀尖指向此方向（例如向上棱刃的图片刀尖朝上）
@export var initial_direction: Vector2 = Vector2.UP

## 初始向外飞行的速度（像素/秒）
@export var initial_speed: float = 1000.0

## 弹簧刚度：值越大，回拉力度越强，摆动频率越高
@export var spring_stiffness: float = 50.0

## 每帧速度衰减系数（0.9 表示保留 90% 的速度，值越接近 1 摆动越久）
@export var damping: float = 0.96

## 振幅阈值（像素）：当棱刃与玩家的垂直距离小于此值，且速度足够小时消失
@export var min_amplitude: float = 20.0

## 最大存活时间（秒），防止无限弹动
@export var lifetime: float = 3.0

# ---------- 内部变量 ----------

## 玩家引用（由生成器设置）
var player_ref: Player

## 当前垂直速度（正数向下，负数向上）
var _velocity_y: float = 0.0

## 生命周期计时器
var life_timer: float = 0.0

## 记录初始方向的符号（用于判断远离/靠近）
var _initial_dir_sign: float = 1.0

## 棱刃的精灵（用于视觉翻转）
@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	# 连接碰撞信号
	area_entered.connect(_on_area_entered)
	life_timer = lifetime

	# 粒子重启
	if has_node("BladeParticles"):
		$BladeParticles.restart()

	# 归一化方向向量
	var dir = initial_direction.normalized()
	_initial_dir_sign = sign(dir.y)  # 向上为 -1，向下为 +1
	# 初始速度 = 方向符号 × 速度大小
	_velocity_y = dir.y * initial_speed

	if player_ref:
		# 起始位置：玩家中心 + 方向偏移 10 像素
		global_position = player_ref.global_position + dir * 10.0


func _physics_process(delta: float) -> void:
	# 倒计时结束，销毁棱刃
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return

	# 玩家已销毁，自身也销毁
	if not player_ref:
		return

	# ----- 弹簧振子运动（仅 Y 轴） -----

	# 1. 计算相对于玩家的垂直偏移
	var offset_y = global_position.y - player_ref.global_position.y

	# 2. 弹簧恢复力产生的加速度（指向玩家，与偏移成正比）
	var acceleration_y = -spring_stiffness * offset_y

	# 3. 更新速度（欧拉积分）
	_velocity_y += acceleration_y * delta

	# 4. 阻尼衰减
	_velocity_y *= damping

	# 5. 更新 Y 位置
	global_position.y += _velocity_y * delta

	# 6. X 轴锁定在玩家 X 坐标
	global_position.x = player_ref.global_position.x

	# 7. 根据运动方向动态翻转精灵
	# 逻辑：当前速度方向与初始方向相同时 -> 远离玩家（刀刃朝外，不翻转）
	#       与初始方向相反时 -> 靠近玩家（刀刃朝内，翻转）
	if sprite:
		var moving_away = sign(_velocity_y) == _initial_dir_sign
		# 假设原图刀尖朝向初始方向，远离时不翻转，靠近时翻转
		sprite.scale.y = 1.0 if moving_away else -1.0

	# 8. 振幅与速度均很小时消失
	if abs(offset_y) < min_amplitude and abs(_velocity_y) < 40.0:
		queue_free()


func _on_area_entered(area: Area2D) -> void:
	# 碰撞到受伤区域
	if area is HurtBox:
		if area.is_boss:
			# Boss：造成 3 点伤害，棱刃消失
			area.take_damage(3)
			queue_free()
		else:
			# 普通敌人：秒杀，棱刃继续飞行
			area.take_damage(999)
