# res://scripts/enemy/boss/l3/EyeComponent.gd
## 眼睛组件：每帧扫描战场信息，打包成字典供大脑决策
class_name EyeComponent

## 当前战场信息包
var info: Dictionary = {}

## 平台边缘检测用的射线长度
const EDGE_RAY_LENGTH: float = 40.0

## 每帧更新战场信息
func update(boss: Boss3, player: Player) -> void:
	if not boss or not player:
		return

	var dist_x = abs(player.global_position.x - boss.global_position.x)
	var dist_y = player.global_position.y - boss.global_position.y
	var player_is_in_front = _is_player_in_front(boss, player)

	info = {
		# ── 距离信息 ──
		"distance_x": dist_x,
		"distance_y": dist_y,
		"player_y": player.global_position.y,

		# ── 血量信息 ──
		"player_hp": player.current_hp,
		"player_max_hp": player.data.max_hp,
		"boss_hp": boss.current_hp,
		"boss_max_hp": boss.data.max_hp,
		"boss_hp_ratio": float(boss.current_hp) / float(boss.data.max_hp),

		# ── 玩家状态 ──
		"player_is_attacking": _is_player_attacking(player),
		"player_is_on_floor": player.is_on_floor(),
		"player_is_in_front": player_is_in_front,
		"player_facing": sign(player.facing_direction),

		# ── Boss 状态 ──
		"boss_is_on_floor": boss.is_on_floor(),
		"boss_facing": sign(boss.facing_direction),

		# ── 环境信息 ──
		"is_at_edge": _is_at_edge(boss),
	}


## 判断玩家是否在 Boss 正面
func _is_player_in_front(boss: Boss3, player: Player) -> bool:
	if boss.facing_direction > 0:
		return player.global_position.x > boss.global_position.x
	else:
		return player.global_position.x < boss.global_position.x


## 判断玩家是否在攻击状态中
func _is_player_attacking(player: Player) -> bool:
	var cur = player.state_machine.current_state
	# 玩家各种攻击状态都算作"正在攻击"
	return cur is GroundAttackState or \
	       cur is AirAttackState or \
	       cur is CrouchAttackState or \
	       cur is SwordDashState or \
	       cur is SwordSpinState or \
	       cur is SwordUppercutState or \
	       cur is SwordDownslashState or \
	       cur is DragonFlashState or \
	       cur is ExterminateReleaseState or \
	       cur is ExterminateChainState


## 平台边缘检测：Boss 脚底前方无地面时返回 true
func _is_at_edge(boss: Boss3) -> bool:
	var space_state = boss.get_world_2d().direct_space_state
	var from = boss.global_position + Vector2(boss.facing_direction * 20.0, 0)
	var to = from + Vector2(0, EDGE_RAY_LENGTH)
	var query = PhysicsRayQueryParameters2D.create(from, to)
	query.collision_mask = 12  # 地面层
	var result = space_state.intersect_ray(query)
	return result.is_empty()