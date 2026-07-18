extends Area2D
class_name FireWall

const ENTER_TARGET_X := 20.0
const ENTER_DURATION := 0.5
const PAUSE_DURATION := 1.0

signal enter_completed

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: Area2D = $HitBox
@onready var stop_wall: StaticBody2D = $StopMoving

var _is_active := false
var _can_follow := false
var _follow_offset := 0.0


func _ready() -> void:
	_is_active = false
	_can_follow = false
	animated_sprite.hide()
	animated_sprite.stop()
	hit_box.monitoring = false
	stop_wall.collision_layer = 0
	add_to_group("fire_wall")


func activate() -> void:
	print("【火墙】进入动画开始")
	_is_active = true
	_can_follow = false

	animated_sprite.show()
	animated_sprite.frame = 0
	animated_sprite.play("default")
	hit_box.monitoring = true
	stop_wall.collision_layer = 4

	var enter_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	enter_tween.tween_property(self, "position:x", ENTER_TARGET_X, ENTER_DURATION)
	await enter_tween.finished

	print("【火墙】到位，停顿 ", PAUSE_DURATION, " 秒")
	await get_tree().create_timer(PAUSE_DURATION).timeout

	var cam = get_viewport().get_camera_2d()
	if cam:
		_follow_offset = global_position.x - cam.global_position.x
	else:
		_follow_offset = -60.0

	_can_follow = true
	enter_completed.emit()
	print("【火墙】开始跟随摄像机，偏移量: ", _follow_offset)


func _process(_delta: float) -> void:
	if not _can_follow:
		return
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	global_position.x = cam.global_position.x + _follow_offset
	global_position.y = 135.0


## BOSS 死亡时火墙退场（向左移出屏幕）
func death_exit() -> void:
	if not _is_active:
		return
	_can_follow = false
	hit_box.monitoring = false
	stop_wall.collision_layer = 0

	var exit_tween = create_tween().set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	exit_tween.tween_property(self, "position:x", position.x - 600.0, 1.5)
	await exit_tween.finished

	animated_sprite.hide()
	animated_sprite.stop()
	_is_active = false
