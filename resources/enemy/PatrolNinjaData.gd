# res://resources/enemy/PatrolNinjaData.gd
# 移动扔镖忍者（PatrolNinja）专属数据
# PatrolNinja 会在地面巡逻，检测到玩家后进入投掷状态
extends BaseEnemyData
class_name PatrolNinjaData

## 投掷冷却时间（秒），玩家在检测范围内每隔 attack_cooldown 秒扔一次飞镖
@export var attack_cooldown: float = 1.0

## 飞镖数据引用（在 Inspector 中绑定 DartData.tres）
@export var dart_data: DartData
