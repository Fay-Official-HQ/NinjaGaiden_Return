# res://scripts/enemy/l1/ChaserNinja.gd
# 追击拳手忍者：追击玩家，遇到断崖或墙壁时跳跃，追踪玩家 Y 轴跳跃
extends BaseEnemy
class_name ChaserNinja

# ── 节点引用（场景中必须包含同名节点） ──
@onready var floor_detect_front: RayCast2D = $FloorDetectFront
@onready var wall_detect_front: RayCast2D = $WallDetectFront

# ── 运行时状态 ──
var _jump_cooldown: float = 0.0


func _ready() -> void:
	super()
	anim.play("walk")


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_apply_gravity(delta)
	_jump_cooldown -= delta
	_face_player()

	# 1. 遇到断崖（前方没地面）或撞墙 → 跳跃
	if is_on_floor():
		if not floor_detect_front.is_colliding() or is_on_wall():
			if _jump_cooldown <= 0.0:
				_do_jump()

	# 2. 追踪玩家 Y 轴跳跃（玩家起跳时跟着跳）
	var player = get_tree().get_first_node_in_group("player")
	if player and player.velocity.y < (data as ChaserNinjaData).player_jump_threshold \
		and is_on_floor() and _jump_cooldown <= 0.0:
		_do_jump()

	# 3. 持续向玩家方向追击
	velocity.x = (data as ChaserNinjaData).chase_speed * (1.0 if facing_right else -1.0)

	move_and_slide()


# ── 跳跃 ──
func _do_jump() -> void:
	var ninja_data = data as ChaserNinjaData
	velocity.y = ninja_data.jump_force
	_jump_cooldown = ninja_data.jump_cooldown


# ── 朝向玩家 ──
func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)
	# 射线也跟随朝向翻转（由场景中 target_position 的 x 符号决定）
	floor_detect_front.target_position.x = abs(floor_detect_front.target_position.x) * (1.0 if facing_right else -1.0)
	wall_detect_front.target_position.x = abs(wall_detect_front.target_position.x) * (1.0 if facing_right else -1.0)


# ── 重力 ──
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += 980.0 * delta
