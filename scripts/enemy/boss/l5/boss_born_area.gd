extends Area2D
class_name BossBornArea

## 破碎后要生成的临时 BOSS（测试用 tower_guard，后续可换正式 Boss 场景）
const TOWER_GUARD_SCENE: PackedScene = preload("res://scenes/enemy/l5/tower_guard.tscn")

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

	# 死亡动画播放完最后一帧的同时，在出生点生成 tower_guard
	var anim: AnimatedSprite2D = glass.get_node("AnimatedSprite2D")
	if anim:
		await anim.animation_finished
	_spawn_guard()


## 在 BornMark 位置生成 tower_guard，挂到关卡根节点的 enemys 下
func _spawn_guard() -> void:
	var guard: Node2D = TOWER_GUARD_SCENE.instantiate()
	var mark: Marker2D = get_tree().current_scene.get_node(born_mark_path)
	if mark:
		guard.global_position = mark.global_position
	else:
		guard.global_position = global_position
	var enemy_parent: Node = get_tree().current_scene.get_node_or_null("enemys")
	if enemy_parent:
		enemy_parent.add_child(guard)
	else:
		get_tree().current_scene.add_child(guard)
	# 生成 boss 后播放战斗 BGM
	AudioManager.play_sound(&"zhandoul5")
