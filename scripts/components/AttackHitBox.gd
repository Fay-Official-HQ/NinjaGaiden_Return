extends Area2D
class_name AttackHitBox

func _ready() -> void:
	monitoring = false
	monitorable = false
	# 添加 Item 层(Layer 7)，才能检测到消耗品，防止手误没有配置碰撞
	collision_mask |= 64  
	area_entered.connect(_on_area_entered)

func _on_area_entered(area: Area2D) -> void:
	if area.has_method("receive_attack"):
		area.receive_attack()
