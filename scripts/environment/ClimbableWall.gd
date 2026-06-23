# res://scripts/environment/ClimbableWall.gd
extends Area2D
class_name ClimbableWall

## 可攀爬方向：LEFT=仅左侧可爬  RIGHT=仅右侧可爬  BOTH=两侧均可爬
enum ClimbableSide { LEFT, RIGHT, BOTH }
@export var climbable_side: ClimbableSide = ClimbableSide.BOTH

var _enter_physics_frame: int = -1


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_collision_layer_value(10, true)
	set_collision_mask_value(1, true)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		body.current_climbable_wall = self
		_enter_physics_frame = Engine.get_physics_frames()


func _on_body_exited(body: Node2D) -> void:
	if body is Player and body.current_climbable_wall == self:
		body.current_climbable_wall = null


## 获取 CollisionShape2D 的实际包围盒（全局坐标）
func get_wall_bounds() -> Rect2:
	var shape_node: CollisionShape2D = get_node_or_null("CollisionShape2D")
	if not shape_node or not shape_node.shape:
		return Rect2(global_position, Vector2.ZERO)
	var rect_size: Vector2 = (shape_node.shape as RectangleShape2D).size
	var offset: Vector2 = shape_node.position
	var top_left: Vector2 = global_position + offset - rect_size / 2.0
	return Rect2(top_left, rect_size)


## 根据玩家位置返回墙壁法线的 x 分量
## -1 = 墙在玩家右边，+1 = 墙在玩家左边
func get_wall_normal_x(player_global_x: float) -> float:
	var bounds := get_wall_bounds()
	var center_x := bounds.position.x + bounds.size.x / 2.0
	if player_global_x < center_x:
		return -1.0
	else:
		return 1.0


## 判断玩家是否可以从设定方向攀爬
## 条件：必须是从区域外刚进来（前 2 帧内），且方向匹配
func can_climb(player: Player) -> bool:
	if _enter_physics_frame < 0:
		return false
	if Engine.get_physics_frames() - _enter_physics_frame > 2:
		return false
	if climbable_side == ClimbableSide.BOTH:
		return true
	var bounds := get_wall_bounds()
	var player_shape := player.get_node("CollisionShape2D")
	var player_hw := 8.0
	if player_shape and player_shape.shape is RectangleShape2D:
		player_hw = (player_shape.shape as RectangleShape2D).size.x / 2.0
	var player_x := player.global_position.x
	if climbable_side == ClimbableSide.LEFT:
		return player_x + player_hw <= bounds.position.x + 8.0
	else:
		return player_x - player_hw >= bounds.end.x - 8.0


## 计算吸附位置：将玩家贴到墙壁碰撞边缘
func get_snap_x(player: Player) -> float:
	var bounds := get_wall_bounds()
	var player_shape := player.get_node("CollisionShape2D")
	var player_hw := 8.0
	if player_shape and player_shape.shape is RectangleShape2D:
		player_hw = (player_shape.shape as RectangleShape2D).size.x / 2.0

	var normal_x := get_wall_normal_x(player.global_position.x)
	if normal_x < 0:
		return bounds.position.x - player_hw
	else:
		return bounds.end.x + player_hw
