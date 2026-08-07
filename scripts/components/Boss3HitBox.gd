# res://scripts/components/Boss3HitBox.gd
## BOSS 假隼龙专用攻击框，默认关闭 monitoring。
## 继承 Area2D（不继承 EnemyHitBox），避免触发玩家代码的 is EnemyHitBox 检测。
## 适用于 SwordHitBox、CrouchHitBox 等仅在攻击动画期间临时开启的攻击框。
extends Area2D
class_name Boss3HitBox

@export var damage: int = 1

func _ready() -> void:
	monitoring = false
	if not area_entered.is_connected(_on_area_entered):
		area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(damage)
