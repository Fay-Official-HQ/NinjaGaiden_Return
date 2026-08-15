extends Area2D
class_name boss5_laser

## 弹道追踪强度（度/秒）：与第四关 EnergyFire 相同，只微微修改弹道。
## 实际值由 BossData_5.laser_homing_turn_rate 通过 initialize 传入（我需要调试）
@export var homing_turn_rate: float = 45.0

var _direction: Vector2 = Vector2.RIGHT
var _speed: float
var _hp: int = 1
var _homing_delay: float = 1.0
var _elapsed: float = 0.0
var _lifetime: float = 5.0
var _life_timer: float = 0.0
var _dead: bool = false
var _death_sound: StringName = &"disiwang"

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var screen_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var enemy_hitbox: Area2D = $EnemyHitBox


func _ready() -> void:
	screen_notifier.screen_exited.connect(_on_screen_exited)
	anim.animation_finished.connect(_on_death_finished)
	if hurt_box:
		hurt_box.took_damage.connect(_on_took_damage)


func initialize(direction: Vector2, speed: float, turn_rate: float = 45.0, hp: int = 1, homing_delay: float = 1.0, lifetime: float = 5.0) -> void:
	_direction = direction.normalized()
	_speed = speed
	homing_turn_rate = turn_rate
	_hp = hp
	_homing_delay = homing_delay
	_lifetime = lifetime
	_elapsed = 0.0
	_life_timer = 0.0
	_dead = false
	_apply_direction_visuals()
	anim.play("flying")


func _process(delta: float) -> void:
	# 扩散阶段：先沿散射方向直线飞行，到期后才开始追踪玩家
	_elapsed += delta
	if _elapsed >= _homing_delay:
		_homing_update(delta)
	global_position += _direction * _speed * delta
	# 超时强制销毁，防止无限飞行造成性能问题
	_life_timer += delta
	if not _dead and _life_timer >= _lifetime:
		_die()


## 弹道追踪：每帧把飞行方向朝玩家缓慢偏转（有限转角，不是完全跟踪）
func _homing_update(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var to_player = (player.global_position - global_position).normalized()
	var angle_diff = wrapf(to_player.angle() - _direction.angle(), -PI, PI)
	var max_turn = deg_to_rad(homing_turn_rate) * delta
	_direction = _direction.rotated(clampf(angle_diff, -max_turn, max_turn))
	# 弹道变化后同步精灵朝向与旋转
	_apply_direction_visuals()


func _apply_direction_visuals() -> void:
	anim.flip_h = _direction.x < 0
	rotation = _direction.angle()


func _on_screen_exited() -> void:
	queue_free()


func _on_took_damage(_damage: int, _is_heavy: bool) -> void:
	_hp -= 1
	if _hp <= 0:
		_die()


## 销毁流程（被攻击打掉 / 存活超时 共用）：播放死亡动画后移除
func _die() -> void:
	if _dead:
		return
	_dead = true
	AudioManager.play_sound(_death_sound)
	set_process(false)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	enemy_hitbox.set_deferred("monitoring", false)
	enemy_hitbox.set_deferred("monitorable", false)
	anim.play("death")


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
