extends BossState
class_name BossFireballState

const MOVE_SPEED: float = 150.0
const REACH_THRESHOLD: float = 10.0
const CHARGE_DURATION: float = 1.0
const FIREBALL_SPEED: float = 200.0
const FIREBALL_SPREAD_ANGLE: float = 0.5

const POINT_NAMES: Array[String] = ["Point_L", "Point_R", "Point_M"]

var _offsets: Array[Vector2] = []
var _current_target_idx: int = 0
var _charge_timer: float = 0.0
var _has_charged: bool = false


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_charge_timer = 0.0
	_has_charged = false

	if not _load_offsets():
		state_machine.change_state_by_name("BossFlyState")
		return

	_current_target_idx = randi() % _offsets.size()

	boss.animated_sprite.play("ball")
	if boss.energy_animated:
		boss.energy_animated.visible = true
		boss.energy_animated.play("default")


func update(_delta: float) -> void:
	pass


func physics_update(delta: float) -> void:
	if not boss._camera_ref:
		return

	if not _has_charged:
		_move_to_position(delta)
	else:
		_charge(delta)


func _move_to_position(delta: float) -> void:
	var center = boss._camera_ref.get_screen_center_position()
	var target = center + _offsets[_current_target_idx]

	var diff = target - boss.global_position
	if diff.length() < REACH_THRESHOLD:
		_has_charged = true
		_charge_timer = CHARGE_DURATION
		return

	var dir = diff / diff.length()
	boss.global_position += dir * MOVE_SPEED * delta

	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)


func _charge(delta: float) -> void:
	_charge_timer -= delta
	if _charge_timer <= 0.0:
		_fire_fireballs()
		return

	if boss.energy_animated:
		boss.energy_animated.flip_h = boss.animated_sprite.flip_h


func _fire_fireballs() -> void:
	var fireball_scene = preload("res://scenes/enemy/boss/l2/boss_fireball.tscn")
	var center_angle = PI / 2.0

	for i in range(-1, 2):
		var angle = center_angle + i * FIREBALL_SPREAD_ANGLE
		var direction = Vector2(cos(angle), sin(angle))

		var fireball = fireball_scene.instantiate()
		fireball.global_position = boss.global_position + Vector2(0, 30)
		fireball.initialize(direction, FIREBALL_SPEED)
		get_tree().current_scene.add_child(fireball)

	AudioManager.play_sound(&"renshuhuoqiu")

	if boss.energy_animated:
		boss.energy_animated.visible = false

	var action = boss.ai_component.get_next_action()
	if action != "" and action != "BossFireballState":
		state_machine.change_state_by_name(action)
	else:
		state_machine.change_state_by_name("BossFlyState")


func exit() -> void:
	if boss.energy_animated:
		boss.energy_animated.visible = false


func _load_offsets() -> bool:
	var fireball_path = boss.get_node_or_null("FireballPath") as Node2D
	if not fireball_path:
		return false

	_offsets.clear()
	for point_name in POINT_NAMES:
		var marker = fireball_path.get_node_or_null(point_name) as Marker2D
		if not marker:
			return false
		_offsets.append(marker.position)

	return _offsets.size() == POINT_NAMES.size()