extends CharacterBody2D
class_name BossStatue

const MAX_HP := 3
const GRAVITY := 980.0
## 魔法阵消失时间（秒）
const MAGIC_FADE_TIME: float = 1.2
## 魔法阵生成间隔（秒）
const MAGIC_INTERVAL: float = 0.25
## 魔法阵数量
const MAGIC_COUNT: int = 6
## 魔法阵缩放
const MAGIC_SCALE: float =0.8
## 魔法阵最小间距
const MAGIC_MIN_SPACING: float = 120.0
## 魔法阵贴图
const MAGIC_TEXTURE = preload("res://assets/shaders/mofazhen.png")
## 火球场景
const FIREBALL_SCENE = preload("res://scenes/enemy/boss/l2/boss_fireball.tscn")
## 下落火球数量
const RAIN_COUNT: int = 14
## 火球间隔（秒）
const RAIN_INTERVAL: float = 0.15
## 火球速度
const RAIN_SPEED: float = 500.0

signal statue_destroyed(spawn_position: Vector2)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var fireball_area: Area2D = $FireballArea

var _current_hp := MAX_HP
var _is_destroyed := false
var _flash_tween: Tween
var _locked_x: float


func _ready() -> void:
	_locked_x = global_position.x
	hurt_box.took_damage.connect(_on_statue_hit)
	animated_sprite.play("default")


func _physics_process(delta: float) -> void:
	if _is_destroyed:
		return
	velocity.x = 0.0
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()
	global_position.x = _locked_x


func _on_statue_hit(_damage: int, _is_heavy: bool) -> void:
	if _is_destroyed:
		return

	_current_hp -= 1
	AudioManager.play_sound(&"shoushang")
	_flash_white()

	if _current_hp > 0:
		return

	_is_destroyed = true
	$HurtBox.set_deferred("monitoring", false)
	$HurtBox.set_deferred("monitorable", false)
	$HitBox.set_deferred("monitoring", false)
	collision_shape.set_deferred("disabled", true)
	AudioManager.play_sound(&"disiwang")

	animated_sprite.play("death")
	await animated_sprite.animation_finished

	animated_sprite.play("isdead")
	await get_tree().create_timer(0.5).timeout
	AudioManager.play_sound(&"mofazhen")
	# 全屏生成 6 个魔法阵，随机先后出现并消失
	await _show_magic_circles()

	# 天空中随机向左下45度角先后落下 7 枚火焰球
	await _rain_fireballs()

	var tween = create_tween()
	tween.tween_property(animated_sprite, "modulate", Color.TRANSPARENT, 1.0)
	await tween.finished

	statue_destroyed.emit(global_position)
	queue_free()


## 生成 6 个全屏魔法阵，逐个随机出现后淡出
func _show_magic_circles() -> void:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return
	var screen_center = cam.get_screen_center_position()
	var screen_size = get_viewport().get_visible_rect().size

	# 计算视口世界范围
	var left = screen_center.x - screen_size.x * 0.5
	var right = screen_center.x + screen_size.x * 0.5
	var top = screen_center.y - screen_size.y * 0.5
	var bottom = screen_center.y + screen_size.y * 0.5

	var last_pos: Vector2

	for i in MAGIC_COUNT:
		var sprite = Sprite2D.new()
		sprite.texture = MAGIC_TEXTURE
		sprite.scale = Vector2(MAGIC_SCALE, MAGIC_SCALE)
		sprite.z_index = 100

		# 随机位置，边缘留 60px 内边距，且不与上一个魔法阵重叠
		var pos: Vector2
		if i == 0:
			pos = Vector2(
				randf_range(left + 60, right - 60),
				randf_range(top + 60, bottom - 60)
			)
		else:
			for _attempt in 20:
				var candidate = Vector2(
					randf_range(left + 60, right - 60),
					randf_range(top + 60, bottom - 60)
				)
				if candidate.distance_to(last_pos) >= MAGIC_MIN_SPACING:
					pos = candidate
					break
			if pos == Vector2.ZERO:
				pos = Vector2(
					randf_range(left + 60, right - 60),
					randf_range(top + 60, bottom - 60)
				)

		sprite.global_position = pos
		last_pos = pos

		get_tree().current_scene.add_child(sprite)

		# 突然出现 → 淡出（Tween 绑定到 sprite 自身，不受雕像被销毁影响）
		var tw = sprite.create_tween()
		tw.tween_interval(0.05)
		tw.tween_property(sprite, "modulate:a", 0.0, MAGIC_FADE_TIME)
		tw.tween_callback(sprite.queue_free)

		# 每个魔法阵之间间隔
		if i < MAGIC_COUNT - 1:
			await get_tree().create_timer(MAGIC_INTERVAL).timeout


## 天空中随机向左下45度角先后落下火球（在 FireballArea 范围内，每次不挨着）
func _rain_fireballs() -> void:
	# 获取 FireballArea 的全局矩形范围
	if not fireball_area:
		return
	var shape_node = fireball_area.get_node("CollisionShape2D") as CollisionShape2D
	var shape = shape_node.shape as RectangleShape2D
	if not shape:
		return
	var area_pos = shape_node.global_position  # 全局坐标（含 CollisionShape2D 偏移）
	var extents = shape.size * 0.5
	var min_x = area_pos.x - extents.x
	var max_x = area_pos.x + extents.x
	var min_y = area_pos.y - extents.y
	var max_y = area_pos.y + extents.y

	# 左下45度方向
	var dir = Vector2(-1, 1).normalized()

	var last_pos: Vector2
	var min_spacing := 60.0

	for i in RAIN_COUNT:
		var fireball = FIREBALL_SCENE.instantiate()

		# 随机位置，且与上一个保持至少 min_spacing 距离
		var pos: Vector2
		if i == 0:
			pos = Vector2(
				randf_range(min_x, max_x),
				randf_range(min_y, max_y)
			)
		else:
			for attempt in 20:
				var candidate = Vector2(
					randf_range(min_x, max_x),
					randf_range(min_y, max_y)
				)
				if candidate.distance_to(last_pos) >= min_spacing:
					pos = candidate
					break
			if pos == Vector2.ZERO:
				pos = Vector2(randf_range(min_x, max_x), randf_range(min_y, max_y))

		fireball.global_position = pos
		fireball.initialize(dir, RAIN_SPEED)
		get_tree().current_scene.add_child(fireball)

		last_pos = pos

		if i < RAIN_COUNT - 1:
			await get_tree().create_timer(RAIN_INTERVAL).timeout


func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)
