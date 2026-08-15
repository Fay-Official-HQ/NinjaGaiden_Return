extends Area2D
class_name BombMissile

## 覆盖式轰炸导弹 —— 从天而降，参考第五关 RPG
## ============================================================
##  1. 朝下方飞行（调用方传 Vector2.DOWN）
##  2. 撞到玩家/地形/被攻击 → 爆炸
##  3. 爆炸中关闭 HurtBox，开启 ExplosionHitBox（爆炸范围伤害）
##  4. 死亡动画结束后关闭 ExplosionHitBox 并销毁
## ============================================================
##
## 【调用规范】（调用方必须遵守此顺序）：
##    missile = scene.instantiate()
##    add_child(missile)                 # 1. 先加入场景（@onready 就绪）
##    missile.global_position = spawn    # 2. 再设位置
##    missile.initialize(dir, speed)     # 3. 最后设方向和速度
## ============================================================

## 初始飞行速度（仅 Inspector 默认值，运行时由 initialize() 覆盖）
@export var default_speed: float = 500.0
## 生命值
@export var hp: int = 1
## 爆炸伤害
@export var explosion_damage: int = 3
## 爆炸音效
@export var death_sound: StringName = &"leidian"

## 当前实际飞行速度（由 initialize() 设置）
var speed: float = 0.0
var _direction: Vector2 = Vector2.DOWN
var _is_exploding: bool = false
## 是否曾进入过屏幕（修复：导弹生成在屏幕外时，Notifier 会在进入场景瞬间触发
## screen_exited，导致导弹「没产生就消失」。只有曾进入屏幕再离开才销毁）
var _ever_entered_screen: bool = false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _explosion_hitbox: Area2D = $ExplosionHitBox
@onready var _hurtbox: Area2D = $HurtBox
@onready var _notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_notifier.screen_entered.connect(_on_screen_entered)
	_notifier.screen_exited.connect(_on_screen_exited)

	if _hurtbox and _hurtbox.has_signal("took_damage"):
		_hurtbox.took_damage.connect(_on_took_damage)

	# 确保爆炸框初始关闭
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)

	# 播放飞行动画
	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("flying"):
		_sprite.play("flying")


## 初始化：方向向量 + 速度（在 add_child 之前调用）
func initialize(dir: Vector2, initial_speed: float) -> void:
	_direction = dir.normalized()
	speed = initial_speed
	if _sprite:
		_sprite.flip_h = (_direction.x < 0)


## 每帧移动
func _process(delta: float) -> void:
	if _is_exploding:
		return
	position += _direction * speed * delta


## 途径1：撞到玩家或地形
func _on_body_entered(_body: Node2D) -> void:
	_trigger_explosion()


## 途径2：被玩家攻击摧毁
func _on_took_damage(_damage: int, _is_heavy: bool = false) -> void:
	if _is_exploding:
		return
	hp -= 1
	if hp <= 0:
		_trigger_explosion()


## 途径3：进入屏幕（记录标志，只有进过屏幕才允许出屏销毁）
func _on_screen_entered() -> void:
	_ever_entered_screen = true


## 途径4：飞出屏幕
func _on_screen_exited() -> void:
	# 生成在屏幕外时 screen_exited 会立即触发，此时不能销毁；
	# 只有「曾进入屏幕后再离开」才销毁，防止导弹在空中凭空消失
	if not _is_exploding and _ever_entered_screen:
		queue_free()


## 爆炸执行：关闭受击框，开启爆炸范围伤害，播放死亡动画后销毁
func _trigger_explosion() -> void:
	if _is_exploding:
		return
	_is_exploding = true
	set_process(false)

	if death_sound != &"":
		AudioManager.play_sound(death_sound)

	if _hurtbox:
		_hurtbox.set_deferred("monitoring", false)
		_hurtbox.set_deferred("monitorable", false)

	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", true)
		_explosion_hitbox.set_deferred("monitorable", true)

	if _sprite and _sprite.sprite_frames and _sprite.sprite_frames.has_animation("death"):
		_sprite.play("death")
		_sprite.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)
	else:
		_cleanup()


func _on_death_anim_finished() -> void:
	_cleanup()


func _cleanup() -> void:
	if _explosion_hitbox:
		_explosion_hitbox.set_deferred("monitoring", false)
		_explosion_hitbox.set_deferred("monitorable", false)
	queue_free()
