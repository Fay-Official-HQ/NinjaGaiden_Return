# res://scripts/player/states/WallState.gd
# 墙壁攀爬状态：吸附在墙壁上，可上下攀爬、蹬墙跳、墙上释放忍术
# 核心规则：velocity.x 始终为 0（禁止左右移动），只有 y 轴受 climb_dir 驱动
extends State

class_name WallState

# 蹬墙跳的水平推力
@export var wall_jump_push_force: float = 170.0
# 蹬墙跳的垂直高度系数（0.7 = 普通跳跃的 70%）
@export var wall_jump_height_factor: float = 0.7
# 爬墙的上下移动速度（像素/秒）
@export var climb_speed: float = 50.0

# 是否正在释放忍术（锁定攀爬移动）
var is_casting: bool = false
var _has_cast: bool = false
var _cast_dir: float = 0.0
# 墙壁法线的 x 分量：-1 = 墙在右边，+1 = 墙在左边
# 用 sign() 可得到推离墙壁的方向
var wall_normal_x: float = 0.0
# 单面攀爬墙引用（Area2D 型），非空表示当前攀爬的是区域型墙壁
var _climbable_wall: ClimbableWall = null 

func enter(_msg: Dictionary = {}) -> void:
	is_casting = false
	player.velocity = Vector2.ZERO
	player.animation.play("wall_idle")
	AudioManager.play_sound(&"tiaoyue")

	_climbable_wall = _msg.get("climbable_wall", null)

	if _climbable_wall:
		# 区域型墙壁：法线由 ClimbableWall 根据玩家位置计算
		wall_normal_x = _climbable_wall.get_wall_normal_x(player.global_position.x)
		player.set_facing_direction(-wall_normal_x)
		# 吸附到墙壁碰撞边缘，防止玩家陷在区域内
		player.global_position.x = _climbable_wall.get_snap_x(player)
	else:
		# 物理型墙壁：从 Godot 物理引擎获取法线
		if player.is_on_wall():
			wall_normal_x = player.get_wall_normal().x
			player.set_facing_direction(-wall_normal_x)

func update(_delta: float) -> void:
	# 忍术播放期间锁定输入，等动画播完自动恢复
	if is_casting:
		var sprite = player.animation.sprite
		if sprite.animation == "wall_ninjutsu" or sprite.animation == "wall_ninjutsu_backward":
			if not _has_cast and sprite.frame >= 1:
				_has_cast = true
				player.ninjutsu.cast_ninjutsu(_cast_dir)
			elif not sprite.is_playing():
				is_casting = false
				player.animation.play("wall_idle")
		return

	# 1. 蹬墙跳：按跳跃 + 方向键推离墙壁
	# sign(wall_normal_x) 就是「远离墙壁」的方向
	# 例：墙在右边 wall_normal_x=-1 → sign=-1 → 只有按左才触发蹬墙跳
	if Input.is_action_just_pressed("jump"):
		if player.input.move_direction == sign(wall_normal_x):
			# 速度直接赋值（不是 +=），覆盖 physics_update 的 velocity.x=0
			player.velocity.x = wall_normal_x * wall_jump_push_force
			player.velocity.y = -player.data.jump_force * wall_jump_height_factor
			# 蹬墙跳后面朝「远离墙壁」方向
			player.set_facing_direction(wall_normal_x)
			
			state_machine.change_state(player.jump_state, {"wall_jump": true})
			player.input.consume_jump() 
			return

	# 2. 墙上释放忍术
	if Input.is_action_just_pressed("ninjutsu"):
		is_casting = true
		_has_cast = false
		# 推离墙壁方向 → 背对墙壁放忍术；否则面朝墙壁放忍术
		if player.input.move_direction == sign(wall_normal_x):
			player.animation.play("wall_ninjutsu_backward")
			_cast_dir = wall_normal_x
		else:
			player.animation.play("wall_ninjutsu")
			_cast_dir = -wall_normal_x
		return

func physics_update(_delta: float) -> void:
	if _climbable_wall:
		# 区域型墙壁：不需要贴墙微力
		player.velocity.x = 0.0
	else:
		# 物理型墙壁：施加微小的贴墙力（2px/s），确保 is_on_wall() 持续生效
		player.velocity.x = -wall_normal_x * 2.0

	# climb_dir 含义：-1=向上爬  0=静止  +1=向下爬
	var climb_dir = 0.0
	if not is_casting:
		if Input.is_action_pressed("nav_up"):
			climb_dir -= 1.0
		if Input.is_action_pressed("nav_down"):
			climb_dir += 1.0
		player.velocity.y = climb_dir * climb_speed

		if climb_dir != 0:
			player.animation.play("wall_climb")
		else:
			player.animation.play("wall_idle")
	else:
		player.velocity.y = 0

	player.move_and_slide()

	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
		return

	if _climbable_wall:
		if _should_exit_area_wall():
			state_machine.change_state(player.jump_state, {"wall_jump": true})
			return
	else:
		if not player.is_on_wall():
			state_machine.change_state(player.jump_state, {"wall_jump": true})
			return


func _should_exit_area_wall() -> bool:
	var bounds = _climbable_wall.get_wall_bounds()
	var player_shape: CollisionShape2D = player.get_node("CollisionShape2D")
	var player_half_h := 15.0
	var player_offset_y := 0.0
	if player_shape and player_shape.shape is RectangleShape2D:
		player_half_h = (player_shape.shape as RectangleShape2D).size.y / 2.0
		player_offset_y = player_shape.position.y
	var player_bottom := player.global_position.y + player_offset_y + player_half_h
	var player_top := player.global_position.y + player_offset_y - player_half_h
	if player_bottom < bounds.position.y:
		return true
	if player_top > bounds.end.y:
		return true
	return false
