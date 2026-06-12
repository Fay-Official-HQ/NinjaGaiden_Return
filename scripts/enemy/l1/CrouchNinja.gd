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
	var ninja_data = data as CrouchNinjaData
	if not ninja_data:
		return

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	var dart = preload("res://scenes/enemy/l1/flying_ninja_dart.tscn").instantiate()
	var dir = (player.global_position - global_position).normalized()

	dart.global_position = global_position + dir * 14
	get_tree().current_scene.add_child(dart)
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
