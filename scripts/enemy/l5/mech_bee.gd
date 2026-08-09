extends CharacterBody2D
class_name MechBee

# ════════════════════════════════════════════════════════════
#  机械蜂（MechBee）—— 参考第四关鬼火，由 MechBeeSpawner 生成
#  行为：
#    - FALL：从生成坐标沿直线以 fall 动画飞到坠落目标点
#    - 到达目标点 → 迅速切换 fly 动画，原地等待 1 秒
#    - CHASE：缓慢飞行追踪玩家，直到被击杀
#    - 生命 1，死亡播放 disiwang 音效 + death 动画（与普通小怪一致）
#    - 无生成音效（与鬼火生成器不同）
# ════════════════════════════════════════════════════════════

enum BeeState { FALL, HOLD, CHASE }

# ── 调试参数（改这里即可调整行为） ──
## 坠落飞行速度（像素/秒）
const FALL_SPEED: float = 300.0
## 判定到达坠落目标的最小距离（像素），小于等于此值视为到达
const FALL_ARRIVE_DISTANCE: float = 10.0
## 到达坠落目标后原地等待的时间（秒），随后开始追击
const HOLD_DURATION: float = 1.0
## 追击玩家的飞行速度（像素/秒），缓慢接近
const CHASE_SPEED: float = 60.0
## 最大血量
const MAX_HP: int = 1
## 死亡音效（与其他小怪一致）
const DEATH_SOUND: StringName = &"disiwang"

var _state: int = BeeState.FALL
var _fall_target: Vector2 = Vector2.ZERO
var _hold_timer: float = 0.0
var _hp: int = 1
var _is_dead: bool = false

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurt_box: HurtBox = $HurtBox
@onready var enemy_hitbox: Area2D = $HitBox


func _ready() -> void:
	_hp = MAX_HP
	hurt_box.took_damage.connect(_on_took_damage)
	anim.play("fall")


## 由生成器调用：设置坠落目标坐标（全局坐标），随后开始 FALL 阶段
func start_fall(target_pos: Vector2) -> void:
	_fall_target = target_pos
	_state = BeeState.FALL
	anim.play("fall")


func _process(delta: float) -> void:
	if _is_dead:
		return

	match _state:
		BeeState.FALL:
			_update_fall(delta)
		BeeState.HOLD:
			_update_hold(delta)
		BeeState.CHASE:
			_update_chase(delta)


# ==================== 坠落（直线飞向目标点） ====================

func _update_fall(delta: float) -> void:
	var to_target = _fall_target - global_position
	if to_target.length() <= FALL_ARRIVE_DISTANCE:
		# 到达坠落目标：切 fly 动画，进入原地等待
		global_position = _fall_target
		_state = BeeState.HOLD
		_hold_timer = 0.0
		anim.play("fly")
		return
	global_position += to_target.normalized() * FALL_SPEED * delta


# ==================== 等待（已切 fly，原地等 1 秒） ====================

func _update_hold(delta: float) -> void:
	_hold_timer += delta
	if _hold_timer >= HOLD_DURATION:
		_state = BeeState.CHASE


# ==================== 追踪（缓慢靠近玩家，永不停止） ====================

func _update_chase(delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var dir = (player.global_position - global_position).normalized()
	global_position += dir * CHASE_SPEED * delta
	anim.flip_h = dir.x < 0


# ==================== 受伤 → 死亡（与普通敌人一致） ====================

func _on_took_damage(amount: int, _is_heavy: bool = false) -> void:
	if _is_dead:
		return
	_hp -= amount
	if _hp <= 0:
		_die()


func _die() -> void:
	_is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	hurt_box.set_deferred("monitoring", false)
	hurt_box.set_deferred("monitorable", false)
	enemy_hitbox.set_deferred("monitoring", false)
	enemy_hitbox.set_deferred("monitorable", false)
	set_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_finished, CONNECT_ONE_SHOT)


func _on_death_finished() -> void:
	if anim.animation == "death":
		queue_free()
