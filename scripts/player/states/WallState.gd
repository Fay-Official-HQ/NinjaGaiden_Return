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
# 墙壁法线的 x 分量：-1 = 墙在右边，+1 = 墙在左边
# 用 sign() 可得到推离墙壁的方向
var wall_normal_x: float = 0.0 

func enter(_msg: Dictionary = {}) -> void:
	is_casting = false
	# 进入墙壁状态时立刻清零所有速度，防止上一状态的惯性带入
	player.velocity = Vector2.ZERO
	player.animation.play("wall_idle")
	
	# 记录墙壁方向，并让角色面朝墙壁
	# 例：墙在右边 → wall_normal_x = -1 → facing_direction = +1（面朝右 = 面朝墙）
	if player.is_on_wall():
		wall_normal_x = player.get_wall_normal().x
		player.set_facing_direction(-wall_normal_x)

func update(_delta: float) -> void:
	# 忍术播放期间锁定输入，等动画播完自动恢复
	if is_casting:
		var sprite = player.animation.sprite
		if (sprite.animation == "wall_ninjutsu" or sprite.animation == "wall_ninjutsu_backward") and not sprite.is_playing():
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
		# 推离墙壁方向 → 背对墙壁放忍术；否则面朝墙壁放忍术
		if player.input.move_direction == sign(wall_normal_x):
			player.animation.play("wall_ninjutsu_backward")
		else:
			player.animation.play("wall_ninjutsu")
		return

func physics_update(_delta: float) -> void:
	# 禁止左右移动，牢牢吸附墙面
	player.velocity.x = 0
	
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
		# 忍术期间悬停
		player.velocity.y = 0
	
	player.move_and_slide()
	
	# 踩到地面 → 站立
	# 【重要】必须在 is_on_wall 之前检查：站在地面上时 is_on_wall 也为 false，
	# 如果先判 is_on_wall 会错误地切到跳跃状态导致翻滚失衡
	if player.is_on_floor():
		state_machine.change_state(player.idle_state)
		return
	
	# 脱离墙壁 → 跳跃
	# 两种情况自然触发：(1)往上爬出墙顶  (2)往下滑出墙底
	# 传递 wall_jump 参数给 JumpState，使其启用 0.15 秒锁时防止立即重抓墙
	if not player.is_on_wall():
		state_machine.change_state(player.jump_state, {"wall_jump": true})
		return
