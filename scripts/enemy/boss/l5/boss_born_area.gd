extends Area2D
class_name BossBornArea

## 破碎后要生成的 BOSS（第5章最终 Boss）
const BOSS_5_SCENE: PackedScene = preload("res://scenes/enemy/boss/l5/Boss_5.tscn")

## 玻璃罩节点（相对本节点的路径，本脚本与 BossGlass2 同属 environment 子节点）
@export var glass_path: NodePath = ^"../BossGlass2"
## 敌人出生点（相对关卡根节点的路径）
@export var born_mark_path: NodePath = ^"Mark/BornMark"

var _triggered: bool = false


func _ready() -> void:
	# 只检测玩家碰撞层
	collision_mask = 1
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player"):
		return
	_triggered = true
	# 一次性触发：立即关闭本触发区域，防止重复进入再次触发
	set_deferred("monitoring", false)

	var glass = get_node(glass_path)
	if glass == null:
		push_error("BossBornArea: 找不到玻璃罩节点 ", glass_path)
		return

	# 播放玻璃罩破碎死亡动画（播完后一直保持死亡状态，不消失）
	AudioManager.play_sound(&"jianci")
	glass.break_glass()

	# 死亡动画播放完最后一帧的同时，在出生点生成 Boss5
	var anim: AnimatedSprite2D = glass.get_node("AnimatedSprite2D")
	if anim:
		await anim.animation_finished
	_spawn_boss()


## 在 BornMark 位置生成 Boss5，挂到关卡根节点的 enemys 下
func _spawn_boss() -> void:
	var boss: Node2D = BOSS_5_SCENE.instantiate()
	var mark: Marker2D = get_tree().current_scene.get_node_or_null(born_mark_path)
	if mark:
		boss._spawn_point = mark.global_position
	else:
		boss._spawn_point = global_position
	var enemy_parent: Node = get_tree().current_scene.get_node_or_null("enemys")
	if enemy_parent:
		enemy_parent.add_child(boss)
	else:
		get_tree().current_scene.add_child(boss)
	# 生成 boss 后播放战斗 BGM
	AudioManager.play_sound(&"zhandoul5")
