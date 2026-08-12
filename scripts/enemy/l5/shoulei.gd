extends Area2D
class_name shoulei


## shoulei —— 抛物线手雷
## ============================================================
##  1. 抛物线投掷（throw_to），以目标点为落点
##  2. 撞到玩家/地形/被攻击 → 爆炸
##  3. 爆炸中关闭 HurtBox，开启 ExplosionHitBox（爆炸范围伤害）
##  4. 死亡动画结束后关闭 ExplosionHitBox 并销毁
## ============================================================
##
## 【调用规范】（调用方必须遵守此顺序）：
##    dart = scene.instantiate()
##    add_child(dart)                    # 1. 先加入场景
##    dart.global_position = spawn_pos   # 2. 再设位置
##    dart.throw_to(target, speed, g)    # 3. 最后设置抛物线初速度
## ============================================================

# ==================== 导出参数（Inspector 调试） ====================

## 初始飞行速度（仅 Inspector 默认值，运行时由 throw_to() 覆盖）
@export var default_speed: float = 300.0
## 手雷自身重力加速度（像素/秒²），越大抛物线越陡
@export var grenade_gravity: float = 500.0
## 生命值
@export var hp: int = 1
## 爆炸伤害
@export var explosion_damage: int = 3
## 爆炸音效
@export var death_sound: StringName = &"leidian"

# ==================== 运行时状态 ====================

## 当前实际飞行速度（仅直线飞行模式使用）
var speed: float = 0.0
## 当前速度向量（抛物线飞行用）
var _velocity: Vector2 = Vector2.ZERO
var _direction: Vector2 = Vector2.RIGHT
## 实际使用的重力加速度（由 throw_to() 设置）
var _gravity: float = 500.0
var _is_exploding: bool = false

# ==================== 节点引用 ====================

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _explosion_hitbox: Area2D = $ExplosionHitBox
@onready var _hurtbox: Area2D = $HurtBox
@onready var _notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	# 信号在 _ready 中统一连接（依赖调用方先 add_child 再调 throw_to 的顺序保证安全）
	body_entered.connect(_on_body_entered)
	_notifier.screen_exited.connect(_on_screen_exited)

	# 连接受伤信号
	if _hurtbox and _hurtbox.has_signal("took_damage"):
		_hurtbox.took_damage.connect(_on_took_damage)

	# 默认重力（未被 throw_to 覆盖时使用）
	_gravity = grenade_gravity

	# 确保爆炸框初始关闭
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)

	# 播放飞行动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("flying"):
		_sprite.play("flying")


## 初始化：直线飞行模式（方向向量 + 速度，在 add_child 之前调用）
func initialize(dir: Vector2, initial_speed: float) -> void:
	_direction = dir.normalized()
	speed = initial_speed
	_velocity = _direction * speed

	# 根据水平方向翻转精灵
	if _sprite:
		_sprite.flip_h = (_direction.x < 0)


## 抛物线投掷：计算初速度使手雷以 target 为落点（在 add_child 之后调用）
##   - flight_speed：水平参考速度（像素/秒），决定飞行时间，越大落地越快
##   - g：手雷重力加速度（像素/秒²），越大抛物线越陡
func throw_to(target: Vector2, flight_speed: float, g: float) -> void:
	_gravity = g
	var start = global_position
	var dx = target.x - start.x
	var dy = target.y - start.y
	# 飞行时间 = 水平距离 / 水平参考速度（保底 0.5 秒，避免贴脸时瞬间落地）
	var time: float = maxf(absf(dx) / maxf(flight_speed, 1.0), 0.5)
	# 抛物线初速度公式：vx = dx / t，vy = (dy - ½·g·t²) / t
	_velocity = Vector2(dx / time, (dy - 0.5 * _gravity * time * time) / time)

	# 根据水平方向翻转精灵
	if _sprite:
		_sprite.flip_h = (_velocity.x < 0)


# ==================== 每帧移动（抛物线） ====================

func _physics_process(delta: float) -> void:
	if _is_exploding:
		return
	# 重力累积 + 位移积分，形成抛物线轨迹
	_velocity.y += _gravity * delta
	position += _velocity * delta


# ==================== 爆炸触发（3 种途径） ====================

## 途径1：撞到地形或玩家身体
func _on_body_entered(_body: Node2D) -> void:
	_trigger_explosion()


## 途径2：被玩家攻击摧毁
func _on_took_damage(_damage: int, _is_heavy: bool = false) -> void:
	if _is_exploding:
		return
	hp -= 1
	if hp <= 0:
		_trigger_explosion()


## 途径3：飞出屏幕
func _on_screen_exited() -> void:
	if not _is_exploding:
		queue_free()


# ==================== 爆炸执行 ====================

func _trigger_explosion() -> void:
	if _is_exploding:
		return
	_is_exploding = true
	set_physics_process(false)

	# 播放爆炸音效
	if death_sound != &"":
		AudioManager.play_sound(death_sound)

	# 关闭受击框（不再接受玩家攻击）
	if _hurtbox:
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)

	# 开启爆炸范围伤害框
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", true)
		_explosion_hitbox.set_deferred("monitorable", true)

	# 播放死亡动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		_sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		# 没有死亡动画，直接清理
		_cleanup()


func _on_death_anim_finished() -> void:
	_cleanup()


func _cleanup() -> void:
	# 关闭爆炸框并销毁
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)
	queue_free()
