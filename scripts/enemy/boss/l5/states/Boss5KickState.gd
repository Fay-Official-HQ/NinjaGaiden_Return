extends BossState
class_name Boss5KickState

## 状态阶段：先垂直对齐玩家水平线，再 summon_down 蓄力，最后朝玩家飞踢
enum Phase { ALIGN, CHARGE, KICK }

var _phase: Phase = Phase.ALIGN
var _target_y: float = 0.0
## 对齐/最低高度参数复用双手发射（phoenix_*），见 BossData_5
var _align_speed: float = 150.0
var _align_tolerance: float = 5.0
var _min_align_y: float = 170.0
var _charge_time: float = 1.0
var _kick_distance: float = 100.0
var _kick_speed: float = 300.0
var _kick_dir: float = 1.0
var _kick_traveled: float = 0.0
var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	var data := boss.data as BossData_5
	if data:
		_align_speed = data.phoenix_align_speed
		_align_tolerance = data.phoenix_align_tolerance
		_min_align_y = data.phoenix_min_align_y
		_charge_time = data.kick_charge_time
		_kick_distance = data.kick_distance
		_kick_speed = data.kick_speed
	_phase = Phase.ALIGN
	_timer = 0.0
	_kick_traveled = 0.0
	# 面朝玩家，垂直飞向玩家的水平线（不高于最低高度限制）
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)
		_target_y = minf(boss.player_ref.global_position.y, _min_align_y)
	boss.animated_sprite.play("fly")


func update(delta: float) -> void:
	if _phase == Phase.CHARGE:
		# 蓄力期间持续面朝玩家
		if boss.player_ref:
			var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
			boss.set_facing_direction(player_dir)
		_timer += delta
		if _timer >= _charge_time:
			_start_kick()
	elif _phase == Phase.KICK:
		pass


func physics_update(delta: float) -> void:
	if _phase == Phase.ALIGN:
		# 从当前位置垂直移动到与玩家接近的水平线（偏离固定飞行路线）
		var diff = _target_y - boss.global_position.y
		if absf(diff) <= _align_tolerance:
			boss.global_position.y = _target_y
			_start_charge()
		else:
			boss.global_position.y += clampf(diff, -_align_speed * delta, _align_speed * delta)
	elif _phase == Phase.KICK:
		# 朝玩家方向直线飞踢，踢满距离后回飞行
		var step = _kick_speed * delta
		_kick_traveled += step
		boss.global_position.x += _kick_dir * step
		if _kick_traveled >= _kick_distance:
			state_machine.change_state_by_name("BossFlyState")


## 到达玩家水平线：切换 summon_down 动画开始蓄力
func _start_charge() -> void:
	_phase = Phase.CHARGE
	_timer = 0.0
	boss.animated_sprite.play("summon_down")


## 蓄力完成：锁定玩家方向，播放 kick 动画开始冲刺
func _start_kick() -> void:
	_phase = Phase.KICK
	_kick_traveled = 0.0
	# 以 Boss 自身为基准锁定玩家所在方向
	if boss.player_ref:
		_kick_dir = 1.0 if boss.player_ref.global_position.x >= boss.global_position.x else -1.0
	boss.set_facing_direction(_kick_dir)
	boss.animated_sprite.play("kick")
	# 冲刺音效与第二关 Boss 冲刺相同
	AudioManager.play_sound(&"jianqianchong")
