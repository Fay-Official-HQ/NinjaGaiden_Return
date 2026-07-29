# res://scripts/enemy/boss/l3/states/Boss3SwordReadyState.gd
## 剑术备战状态：播放 sword_ready，被攻击时自动格挡（音效+火花），持续后随机释放剑术
extends Boss3State
class_name Boss3SwordReadyState

var _timer: float = 0.0

const SPARK_TEXTURE = preload("res://assets/shaders/huohua.png")
var _spark_pos: Marker2D = null

# 可选剑术列表
var _sword_skills: Array[String] = [
	"Boss3SwordDashState",
	"Boss3SwordSpinState",
	"Boss3SwordUppercutState",
	"Boss3FlightToTopState",
]

func enter(_msg: Dictionary = {}) -> void:
	super()
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("sword_ready")
	_timer = boss.data.sword_ready_duration

func update(delta: float) -> void:
	_timer -= delta
	if _timer <= 0.0:
		var chosen = _sword_skills[randi() % _sword_skills.size()]
		state_machine.change_state_by_name(chosen)

func physics_update(delta: float) -> void:
	if not boss.is_on_floor():
		boss.velocity.y += boss.data.gravity * delta
	boss.move_and_slide()

func spawn_block_spark() -> void:
	if not _spark_pos:
		_spark_pos = boss.get_node_or_null("Visual/BlockSparkPos")
	if not _spark_pos:
		return
	for i in 5:
		var s = Sprite2D.new()
		s.texture = SPARK_TEXTURE
		s.modulate = Color.WHITE
		s.scale = Vector2(randf_range(0.8, 1.5), randf_range(0.8, 1.5))
		s.rotation = randf_range(0, TAU)
		var start_pos = _spark_pos.position + Vector2(randf_range(-6, 6), randf_range(-4, 4))
		s.position = start_pos
		s.z_index = 100
		boss.add_child(s)
		var peak_x = start_pos.x + (-boss.facing_direction) * randf_range(25, 50)
		var peak_y = start_pos.y - randf_range(15, 30)
		var land_y = peak_y + randf_range(25, 45)
		var rise_time = 0.1
		var fall_time = randf_range(0.12, 0.18)
		var tw = create_tween()
		tw.set_parallel(true)
		tw.tween_property(s, "modulate:a", 0.0, rise_time + fall_time)
		tw.tween_property(s, "position", Vector2(peak_x, peak_y), rise_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		tw.tween_property(s, "position:y", land_y, fall_time).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD).set_delay(rise_time)
		tw.tween_callback(s.queue_free).set_delay(rise_time + fall_time)
