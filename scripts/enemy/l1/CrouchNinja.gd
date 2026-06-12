# 下蹲丢镖忍者：原地不动，面朝玩家，全屏检测，持续扔不可摧毁飞镖
extends BaseEnemy
class_name CrouchNinja

enum NinjaState { IDLE, THROW }

@onready var detect_range: Area2D = $DetectRange

var _state: int = NinjaState.IDLE
var _throw_cooldown: float = 0.0


func _ready() -> void:
	super()
	detect_range.body_entered.connect(_on_player_entered)
	detect_range.body_exited.connect(_on_player_exited)
	anim.animation_finished.connect(_on_throw_finished)
	anim.play("idle")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_face_player()
	velocity.x = 0.0

	match _state:
		NinjaState.IDLE:
			_update_idle(delta)
		NinjaState.THROW:
			_update_throw(delta)

	move_and_slide()


func _update_idle(_delta: float) -> void:
	anim.play("idle")


func _update_throw(delta: float) -> void:
	if anim.animation != "throw":
		anim.play("idle")

	_throw_cooldown -= delta
	if _throw_cooldown <= 0.0:
		_throw_dart()
		_throw_cooldown = (data as CrouchNinjaData).attack_cooldown


func _throw_dart() -> void:
	# 【调试飞镖起始位置】关键修改点：
	#   1. 位置：dart.global_position = global_position + dir * 14
	#      - 14 是飞镖出生点偏离忍者中心的像素距离
	#      - 调大→飞镖更远离身体，调小→飞镖更贴近身体，负值→飞镖从身后飞出
	#   2. 方向：dir = (player - 忍者位置).normalized()
	#      - 这是直接指向玩家的单位向量
	#      - 如果想调角度偏移，可以用 dir.rotated(deg_to_rad(角度值))
	#      - 例：dir.rotated(deg_to_rad(-5)) 向上偏移5度，玩家可蹲下躲
	#   3. 场景预览调试技巧：在编辑器里选中 CrouchNinja 实例，
	#      把飞镖场景从文件系统拖到场景窗口预览位置，
	#      配合 dir * 14 的偏移量估算实际出生点
	var ninja_data = data as CrouchNinjaData
	if not ninja_data:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dart = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn").instantiate()
	var dir = (player.global_position - global_position).normalized()

	# 【调试点】修改 14 这个值调整飞镖出生水平偏移量（像素）
	#   数值参考：14≈半个角色宽度，20≈一个角色宽度
	# 【调试点】Vector2(0, 7) 的 7 是垂直偏移（正数=向下），
	#   调大→飞镖更偏下飞，调小/负值→飞镖更偏上飞
	dart.global_position = global_position + dir * 14 + Vector2(0, 7)
	get_tree().current_scene.add_child(dart)
	# 【调试点】dart.initialize 的第二个参数是飞镖速度，可在 CrouchNinjaData.tres 中直接调整
	dart.initialize(dir, ninja_data.dart_speed)

	anim.play("throw")


func _on_throw_finished() -> void:
	if is_dead:
		return
	anim.play("idle")


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)


func _on_player_entered(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = NinjaState.THROW
	_throw_cooldown = 0.0


func _on_player_exited(body: Node) -> void:
	if not body.is_in_group("player"):
		return
	_state = NinjaState.IDLE


func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
