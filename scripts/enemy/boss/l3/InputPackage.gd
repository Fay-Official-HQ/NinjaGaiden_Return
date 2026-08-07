# res://scripts/enemy/boss/l3/InputPackage.gd
## 按键信号包：大脑输出 → 双手执行
## 每个字段代表一个"按键信号"，类似真人玩家的按键输入
class_name InputPackage

# ── 移动方向（每帧设置） ──
var move_x: int = 0   # -1: 左, 0: 停, 1: 右
var move_y: int = 0   # -1: 下蹲, 0: 不动

# ── 基础动作（脉冲式，一帧触发即释放） ──
var jump: bool = false
var attack: bool = false
var block: bool = false

# ── 跳跃后空中投掷（跳跃到最高点时投掷飞镖，与 jump 配合使用） ──
var jump_air_throw: bool = false

# ── 忍术（各自独立按键，对应 4 种投射物） ──
var ninjutsu_fire: bool = false      # 0-火焰弹(3发斜上)
var ninjutsu_fireball: bool = false  # 1-火球术(3发斜下)
var ninjutsu_boomerang: bool = false # 2-回旋镖(水平弹簧)
var ninjutsu_edge_blade: bool = false# 3-冷刃(垂直弹簧)

# ── 剑术（各自独立按键） ──
var sword_dash: bool = false
var sword_spin: bool = false
var sword_uppercut: bool = false
var sword_downslash: bool = false

# ── 特殊飞行（独占，执行时忽略其他按键） ──
var fly_to_top: bool = false
var fly_to_left: bool = false
var fly_to_right: bool = false

# ── 投掷飞镖（远程消耗） ──
var throw_dart: bool = false

# ── 必杀技 ──
var special_move: bool = false

## 清空所有按键（每帧大脑生成前调用）
func clear() -> void:
	move_x = 0
	move_y = 0
	jump = false
	attack = false
	block = false
	jump_air_throw = false
	ninjutsu_fire = false
	ninjutsu_fireball = false
	ninjutsu_boomerang = false
	ninjutsu_edge_blade = false
	sword_dash = false
	sword_spin = false
	sword_uppercut = false
	sword_downslash = false
	fly_to_top = false
	fly_to_left = false
	fly_to_right = false
	throw_dart = false
	special_move = false
