extends Area2D
class_name LightningBolt

var _life: float = 0.0
var _damage_activated: bool = false

const LIFETIME: float = 0.6
const ACTIVATE_FRAME: int = 1

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var hit_box: Area2D = $EnemyHitBox

func _ready() -> void:
	animated_sprite.play("default")
	hit_box.set_deferred("monitoring", false)

func _physics_process(delta: float) -> void:
	_life += delta
	if _life >= LIFETIME:
		queue_free()
		return
	if not _damage_activated and animated_sprite.frame >= ACTIVATE_FRAME:
		_damage_activated = true
		hit_box.set_deferred("monitoring", true)
		_flash_screen()

func _flash_screen() -> void:
	var viewport = get_viewport()
	if not viewport:
		return
	var overlay = ColorRect.new()
	overlay.color = Color(1.0, 1.0, 1.0, 0.6)
	overlay.size = viewport.get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	canvas_layer.add_child(overlay)
	viewport.add_child(canvas_layer)
	var tw = create_tween()
	tw.tween_property(overlay, "color:a", 0.0, 0.15)
	tw.tween_callback(func():
		canvas_layer.queue_free()
	)
