# res://scripts/enemy/l2/chaser_monster.gd
# 追捕怪物：生成后朝玩家方向奔跑 → 接近时跳跃撞向玩家 → 出屏消失
# 所有数据硬编码在代码中，不需要绑定 data 资源
extends BaseEnemy
class_name ChaserMonster

const CHASE_SPEED: float = 120.0
const JUMP_FORCE: float = -250.0
const JUMP_DISTANCE: float = 100.0
const JUMP_STUN: float = 0.3
const SCREEN_MARGIN: float = 50.0
const DEATH_SOUND: StringName = &"disiwang"

enum State { CHASE, JUMP_ATTACK }

var _state: int = State.CHASE
var _jump_stun: float = 0.0


func _ready() -> void:
	super()
	current_hp = 1
	_face_player()
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity.y += 980.0 * delta

	_jump_stun -= delta
	_face_player()

	match _state:
		State.CHASE:
			_chase_update()
		State.JUMP_ATTACK:
			_jump_attack_update()

	move_and_slide()
	_check_screen_exit()


func _chase_update() -> void:
	velocity.x = CHASE_SPEED * (1.0 if facing_right else -1.0)
	anim.play("walk")

	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	if not is_on_floor():
		return
	if _jump_stun > 0.0:
		return

	var dist_x = abs(player.global_position.x - global_position.x)
	if dist_x <= JUMP_DISTANCE:
		_do_jump_attack()


func _jump_attack_update() -> void:
	anim.play("jump")
	if is_on_floor():
		_state = State.CHASE
		_jump_stun = JUMP_STUN
		_face_player()
		anim.play("walk")


func _do_jump_attack() -> void:
	_state = State.JUMP_ATTACK
	velocity.y = JUMP_FORCE
	velocity.x = CHASE_SPEED * 1.5 * (1.0 if facing_right else -1.0)
	anim.play("jump")


func _die() -> void:
	is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


func _check_screen_exit() -> void:
	var viewport_rect = get_viewport_rect()
	var canvas_transform = get_viewport().get_canvas_transform()
	var screen_pos = canvas_transform * global_position
	if screen_pos.x < -SCREEN_MARGIN or screen_pos.x > viewport_rect.size.x + SCREEN_MARGIN:
		queue_free()
	if screen_pos.y < -SCREEN_MARGIN or screen_pos.y > viewport_rect.size.y + SCREEN_MARGIN:
		queue_free()


func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)
