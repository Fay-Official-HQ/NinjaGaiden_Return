extends BossState
class_name BossLaserState

enum Phase { CHARGE, FIRE }

var _phase: int = Phase.CHARGE
var _charge_timer: float = 0.0
var _fire_timer: float = 0.0
var _laser_scene: PackedScene = preload("res://scenes/enemy/boss/boss_laser.tscn")
var _charge_modulate_direction: float = 1.0
var _warning_line: Sprite2D
var _warning_alpha_timer: float = 0.0

const CHARGE_DURATION: float = 1.0
const WARNING_LINE_LENGTH: float = 500.0   # 预警线长度（像素），=战斗屏幕宽度
const WARNING_LINE_HEIGHT: float = 10.0  # 预警线高度（像素）

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("lasercharge")
	boss.animated_sprite.modulate = Color(0.8, 0.0, 0.0, 1.0)
	_charge_modulate_direction = 1.0
	_warning_alpha_timer = 0.0
	_create_warning_line()
	_phase = Phase.CHARGE
	_charge_timer = CHARGE_DURATION
	_fire_timer = 0.0

func update(delta: float) -> void:
	match _phase:
		Phase.CHARGE:
			_charge_timer -= delta
			boss.animated_sprite.modulate.r += _charge_modulate_direction * 3.0 * delta
			if boss.animated_sprite.modulate.r >= 1.0:
				boss.animated_sprite.modulate.r = 1.0
				_charge_modulate_direction = -1.0
			elif boss.animated_sprite.modulate.r <= 0.3:
				boss.animated_sprite.modulate.r = 0.3
				_charge_modulate_direction = 1.0
			if _charge_timer <= 0.0:
				_fire_laser()
			_update_warning_line()

		Phase.FIRE:
			_fire_timer -= delta
			if _fire_timer <= 0.0:
				_cleanup()
				state_machine.change_state_by_name("BossIdleState")

func physics_update(_delta: float) -> void:
	boss.velocity.x = 0.0

func exit() -> void:
	_cleanup()

func _fire_laser() -> void:
	_phase = Phase.FIRE
	_fire_timer = BossLaser.MAX_LENGTH / BossLaser.SPEED + 0.3
	boss.animated_sprite.modulate = Color.WHITE
	boss.animated_sprite.play("laser")
	_destroy_warning_line()
	var laser = _laser_scene.instantiate() as BossLaser
	laser.initialize(boss.facing_direction, boss.global_position)
	boss.get_parent().add_child(laser)

func _cleanup() -> void:
	boss.animated_sprite.modulate = Color.WHITE
	_destroy_warning_line()

func _create_warning_line() -> void:
	var img = Image.create(1, 1, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color.WHITE)
	var tex = ImageTexture.create_from_image(img)
	_warning_line = Sprite2D.new()
	_warning_line.texture = tex
	_warning_line.centered = false
	_warning_line.scale = Vector2(WARNING_LINE_LENGTH * boss.facing_direction, WARNING_LINE_HEIGHT)
	_warning_line.position = Vector2(20.0 * boss.facing_direction, 0)   # X=水平偏移（正=靠前，负=靠后），Y=垂直偏移（负=抬高，正=降低）
	boss.add_child(_warning_line)

func _update_warning_line() -> void:
	if not _warning_line or not is_instance_valid(_warning_line):
		return
	_warning_alpha_timer += 0.05
	var alpha = 0.15 + sin(_warning_alpha_timer * 8.0) * 0.1
	_warning_line.modulate = Color(1.0, 0.1, 0.1, max(alpha, 0.05))

func _destroy_warning_line() -> void:
	if _warning_line and is_instance_valid(_warning_line):
		_warning_line.queue_free()
		_warning_line = null

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)
