extends BaseEnemy
class_name DefenseEnemy

# ════════════════════════════════════════════════════════════
#  防御兵（DefenseEnemy）
#  行为：防御 / 发射两个状态轮回切换，各持续 3 秒
#    - 防御状态：抵御所有攻击，播放 def 动画，每次受击播放防御音效
#    - 发射状态：播放 throw 动画，1 秒后向玩家方向发射子弹，
#      继续维持动画直到 3 秒结束，随后切回防御
#    - 发射状态下可被攻击，血量 1，死亡播放 death 动画 + disiwang 音效
#    - 时刻面对玩家
# ════════════════════════════════════════════════════════════

enum DefenseState { DEFEND, THROW }

# ── 调试参数（改这里即可调整行为） ──
## 每个状态持续时长（秒）
const STATE_DURATION: float = 1.0
## 玩家距离超过该值时强制防御状态（不发子弹）；不超过该值时正常轮回防御/发射
const DEFEND_RANGE: float = 220.0
## 进入发射状态后，延迟发射子弹的时间（秒）
const THROW_DELAY: float = 0.5
## 子弹飞行速度
const BULLET_SPEED: float = 350.0
## 子弹生成点相对本体的偏移（X 方向随面朝方向自动翻转）
const BULLET_OFFSET: Vector2 = Vector2(14, -3)
## 重力加速度（保证贴地，不需要可改为 0）
const GRAVITY: float = 980.0
## 防御音效（BOSS1 同款）
const DEFEND_SOUND: StringName = &"fangyu"
## 发射音效（与士兵射手一致）
const THROW_SOUND: StringName = &"shibingfashe"
## 死亡音效（与其他小怪一致）
const DEATH_SOUND: StringName = &"disiwang"

var _state: int = DefenseState.DEFEND
var _state_timer: float = 0.0
var _throw_fired: bool = false

var _bullet_scene: PackedScene = preload("res://scenes/enemy/l2/soldier_bullet.tscn")


func _ready() -> void:
	super()
	current_hp = 1  # 血量 1，发射状态一碰就死
	_enter_defend()


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	# 时刻面对玩家
	_face_player()

	# 重力贴地（BULLET_OFFSET 为固定站立敌人，无需水平移动）
	if not is_on_floor():
		velocity.y += GRAVITY * delta
	move_and_slide()

	# 玩家距离超过 DEFEND_RANGE 时强制防御状态，不发子弹
	var player = get_tree().get_first_node_in_group("player")
	if player and global_position.distance_to(player.global_position) > DEFEND_RANGE:
		if _state != DefenseState.DEFEND:
			_enter_defend()
		return

	_state_timer += delta
	match _state:
		DefenseState.DEFEND:
			if _state_timer >= STATE_DURATION:
				_enter_throw()
		DefenseState.THROW:
			# 播放 throw 动画，满 1 秒发射一次，然后维持动画直到状态结束
			if not _throw_fired and _state_timer >= THROW_DELAY:
				_throw_fired = true
				_fire_bullet()
			if _state_timer >= STATE_DURATION:
				_enter_defend()


# ==================== 状态切换 ====================

func _enter_defend() -> void:
	_state = DefenseState.DEFEND
	_state_timer = 0.0
	_throw_fired = false
	anim.play("def")


func _enter_throw() -> void:
	_state = DefenseState.THROW
	_state_timer = 0.0
	_throw_fired = false
	anim.play("throw")


# ==================== 发射子弹 ====================

func _fire_bullet() -> void:
	var dir: float = 1.0 if facing_right else -1.0
	var origin: Vector2 = global_position + Vector2(BULLET_OFFSET.x * dir, BULLET_OFFSET.y)
	var bullet = _bullet_scene.instantiate()
	bullet.global_position = origin
	get_tree().current_scene.add_child(bullet)
	bullet.initialize(dir, BULLET_SPEED)
	AudioManager.play_sound(THROW_SOUND)


# ==================== 受击 / 死亡 ====================

## 覆盖基类：防御状态抵御所有攻击（只播音效不掉血），发射状态正常受伤
func _on_took_damage(_amount: int, _is_heavy: bool = false) -> void:
	if is_dead:
		return
	if _state == DefenseState.DEFEND:
		AudioManager.play_sound(DEFEND_SOUND)
		return
	current_hp -= _amount
	if current_hp <= 0:
		_die()


## 覆盖基类：不依赖 data 资源，音效动画写死在代码里
func _die() -> void:
	is_dead = true
	AudioManager.play_sound(DEATH_SOUND)
	hitbox.set_deferred("monitoring", false)
	hitbox.set_deferred("monitorable", false)
	hurtbox.set_deferred("monitoring", false)
	hurtbox.set_deferred("monitorable", false)
	set_physics_process(false)
	anim.play("death")
	anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)


# ==================== 朝向 ====================

func _face_player() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	_set_facing(player.global_position.x > global_position.x)
