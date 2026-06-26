extends CharacterBody2D
class_name Boss

@export var data: BossData

@onready var animated_sprite: AnimatedSprite2D = $Visual/AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtRoot/HurtBox
@onready var state_machine: BossStateMachine = $BossStateMachine
@onready var boss_ui: BossUI = $BossUI

var player_ref: Player
var current_hp: int
var is_dead: bool = false
var facing_direction: float = 1.0
var _flash_tween: Tween

func _ready() -> void:
	current_hp = data.max_hp
	player_ref = get_tree().get_first_node_in_group("player")
	hurt_box.took_damage.connect(_on_took_damage)
	boss_ui.initialize(data)
	boss_ui.update_hp(current_hp)
	boss_ui.show_with_animation()

func _process(delta: float) -> void:
	if is_dead:
		return
	state_machine.update(delta)

func _physics_process(delta: float) -> void:
	if is_dead:
		return
	if not is_on_floor():
		velocity.y += 980.0 * delta
	var prev_x = global_position.x
	state_machine.physics_update(delta)
	move_and_slide()
	if not is_dead and abs(velocity.x) < 1.0:
		global_position.x = prev_x

func _on_took_damage(damage: int, is_heavy: bool) -> void:
	if is_dead:
		return
	current_hp = max(0, current_hp - damage)
	boss_ui.update_hp(current_hp)
	if current_hp <= 0:
		state_machine.change_state_by_name("BossDeathState")
	elif is_heavy:
		state_machine.change_state_by_name("BossHurtState")
	else:
		_flash_white()

func _flash_white() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(animated_sprite, "modulate", Color(3.0, 3.0, 3.0, 1.0), 0.15)
	_flash_tween.tween_property(animated_sprite, "modulate", Color.WHITE, 0.15)

func set_facing_direction(direction: float) -> void:
	if direction == 0:
		return
	facing_direction = 1.0 if direction > 0 else -1.0
	animated_sprite.flip_h = facing_direction < 0

func die() -> void:
	is_dead = true
	set_physics_process(false)
	set_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)

func is_ground_ahead() -> bool:
	var space_state = get_world_2d().direct_space_state
	var from = global_position + Vector2(0, 0)
	var to = global_position + Vector2(facing_direction * 50.0, 40.0)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12
	var result = space_state.intersect_ray(query)
	return not result.is_empty()
