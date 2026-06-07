# res://scripts/ninjutsu/boomerang.gd
extends Area2D
class_name Boomerang
#最远距离
@export var throw_speed: float = 1500.0  
#弹力
@export var spring_stiffness: float = 50.0 
#阻尼
@export var damping: float = 0.96
@export var min_amplitude: float = 8.0
@export var lifetime: float = 3

var player_ref: Player
var base_direction: Vector2
var facing_override: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var life_timer: float = 0.0

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	life_timer = lifetime

	if has_node("BoomerangParticles"):
		$BoomerangParticles.restart()

	if facing_override != 0:
		base_direction = Vector2(1.0 if facing_override > 0 else -1.0, 0)
	elif player_ref:
		base_direction = Vector2(player_ref.facing_direction, 0)
	else:
		base_direction = Vector2.RIGHT

	_velocity = base_direction * throw_speed

	if player_ref:
		global_position = player_ref.global_position + base_direction * 10.0

func _physics_process(delta: float) -> void:
	life_timer -= delta
	if life_timer <= 0.0:
		queue_free()
		return

	if not player_ref:
		return

	var offset = global_position - player_ref.global_position

	var acceleration = -spring_stiffness * offset

	_velocity += acceleration * delta

	_velocity *= damping

	global_position += _velocity * delta

	if has_node("BoomerangParticles"):
		var mat = $BoomerangParticles.process_material as ParticleProcessMaterial
		if mat:
			mat.direction = Vector3(sign(_velocity.x) if abs(_velocity.x) > 0 else base_direction.x, 0, 0)

	if offset.length() < min_amplitude and _velocity.length() < 50.0:
		queue_free()

func _on_area_entered(area: Area2D) -> void:
	if area is HurtBox:
		area.take_damage(1)
		if area.is_boss:
			queue_free()
