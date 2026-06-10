# 敌人系统架构设计文档
# 《忍者龙剑传：归来》v1.0
# 引擎：Godot 4.6 | 开发工具：Trae + DeepSeek

---

## 一、设计原则

1. **与现有架构对齐**：沿用项目已有的 组件化(Component) + 状态机(FSM) 双层模式
2. **数据驱动**：所有数值存入 `.tres` Resource，不在代码中硬编码
3. **AI友好**：每个文件职责单一，类名/方法名语义明确，避免隐式依赖
4. **复用优先**：小怪共享基类和死亡系统，飞镖/激光为独立可复用场景

---

## 二、目录结构

```
scripts/
├── enemy/
│   ├── base/
│   │   ├── BaseEnemy.gd              # 小怪基类
│   │   ├── EnemyHurtBox.gd           # 小怪受击框（复用）
│   │   └── EnemyDeathHandler.gd      # 统一死亡处理组件
│   ├── patrol/
│   │   └── PatrolEnemy.gd            # 地面巡逻怪
│   ├── flying/
│   │   ├── BatEnemy.gd               # 蝙蝠
│   │   ├── EagleEnemy.gd             # 老鹰
│   │   └── FlyingNinja.gd            # 飞天忍者
│   ├── ninja/
│   │   ├── WallNinja.gd              # 攀墙忍者
│   │   ├── CrouchNinja.gd            # 下蹲扔镖忍者
│   │   ├── PatrolNinja.gd            # 移动扔镖忍者
│   │   ├── Gunner.gd                 # 枪手
│   │   └── ChaserNinja.gd            # 追击拳手忍者
│   └── boss/
│       ├── Boss.gd                   # BOSS主类
│       ├── BossStateMachine.gd       # BOSS专用状态机
│       └── states/
│           ├── BossState.gd          # BOSS状态基类
│           ├── BossIdleState.gd
│           ├── BossMoveState.gd
│           ├── BossChargeState.gd    # 冲撞
│           ├── BossJumpState.gd
│           ├── BossStabState.gd      # 刺击
│           ├── BossSlashState.gd     # 挥刀
│           ├── BossEdgeBladeState.gd # 棱刃
│           ├── BossFlameState.gd     # 火焰
│           ├── BossThunderState.gd   # 雷电（必杀）
│           └── BossAppearState.gd    # 显现
├── projectile/
│   ├── Dart.gd                       # 飞镖（小怪/BOSS通用）
│   ├── Laser.gd                      # 激光（枪手专用）
│   ├── BossEdgeBlade.gd              # BOSS棱刃投射物
│   ├── BossFlame.gd                  # BOSS火焰投射物
│   └── Thunder.gd                    # 雷电（必杀）
└── components/
    └── ThrowComponent.gd             # 投射物发射组件（小怪复用）

resources/
└── enemy/
    ├── EnemyData.tres                # 小怪通用数据基类
    ├── PatrolEnemyData.tres
    ├── BatData.tres
    ├── EagleData.tres
    ├── FlyingNinjaData.tres
    ├── WallNinjaData.tres
    ├── CrouchNinjaData.tres
    ├── PatrolNinjaData.tres
    ├── GunnerData.tres
    ├── ChaserNinjaData.tres
    ├── DartData.tres
    ├── LaserData.tres
    └── BossData.tres                 # BOSS专用数据资源

scenes/
├── enemy/
│   ├── patrol_enemy.tscn
│   ├── bat_enemy.tscn
│   ├── eagle_enemy.tscn
│   ├── flying_ninja.tscn
│   ├── wall_ninja.tscn
│   ├── crouch_ninja.tscn
│   ├── patrol_ninja.tscn
│   ├── gunner.tscn
│   └── chaser_ninja.tscn
├── projectile/
│   ├── dart.tscn
│   ├── laser.tscn
│   ├── boss_edge_blade.tscn
│   ├── boss_flame.tscn
│   └── thunder.tscn
└── boss/
    └── boss.tscn
```

---

## 三、数据层设计（Resource）

### 3.1 小怪通用数据基类

```gdscript
# resources/enemy/EnemyData.gd
class_name EnemyData
extends Resource

@export var max_hp: int = 1
@export var move_speed: float = 60.0
@export var contact_damage: int = 1
@export var death_anim: String = "death"   # 统一爆炸动画名
```

### 3.2 各小怪专属数据（继承 EnemyData）

```gdscript
# BatData.gd
class_name BatData
extends EnemyData
@export var sine_amplitude: float = 20.0   # 正弦波振幅（像素）
@export var sine_frequency: float = 2.0    # 正弦波频率（Hz）

# EagleData.gd
class_name EagleData
extends EnemyData
@export var dive_curve_strength: float = 80.0  # 俯冲曲线弯曲度
@export var turn_deceleration: float = 120.0   # 掉头减速度

# FlyingNinjaData.gd
class_name FlyingNinjaData
extends EnemyData
@export var rise_speed: float = 150.0
@export var dart_data: DartData                # 引用飞镖数据

# CrouchNinjaData.gd
class_name CrouchNinjaData
extends EnemyData
@export var attack_cooldown: float = 3.0
@export var dart_data: DartData

# GunnerData.gd
class_name GunnerData
extends EnemyData
@export var warn_duration: float = 0.5        # 红色闪烁提示时长
@export var laser_data: LaserData

# ChaserNinjaData.gd
class_name ChaserNinjaData
extends EnemyData
@export var chase_speed: float = 120.0
@export var jump_force: float = -200.0        # 追击跳跃力
```

### 3.3 投射物数据

```gdscript
# DartData.gd
class_name DartData
extends Resource
@export var speed: float = 150.0
@export var damage: int = 1
@export var max_hp: int = 1

# LaserData.gd
class_name LaserData
extends Resource
@export var speed: float = 600.0
@export var damage: int = 1
# 注意：激光不可被摧毁，无 max_hp
```

### 3.4 BOSS数据资源

```gdscript
# BossData.gd
class_name BossData
extends Resource

# === 基础属性 ===
@export var max_hp: int = 32
@export var phase2_threshold: float = 0.5     # 强化阶段血量比例

# === 伤害数值 ===
@export var contact_damage: int = 1
@export var normal_attack_damage: int = 2
@export var ultimate_damage: int = 3           # 雷电

# === 移动速度 ===
@export var move_speed: float = 60.0
@export var charge_speed: float = 240.0        # 冲撞速度
@export var stab_speed: float = 280.0          # 刺击速度

# === 状态冷却 ===
@export var state_cooldown_normal: float = 5.0
@export var state_cooldown_phase2: float = 3.0

# === 受击硬直 ===
@export var hit_stun_duration: float = 0.5

# === 跳跃 ===
@export var jump_crouch_duration: float = 1.0  # 蹲下蓄力时长
@export var jump_force: float = -380.0

# === 蓄力时长（刺击/挥刀/棱刃/火焰） ===
@export var windup_duration: float = 1.0

# === 棱刃 ===
@export var edge_blade_duration: float = 3.0
@export var edge_blade_stiffness: float = 200.0
@export var edge_blade_damping: float = 0.85
@export var edge_blade_initial_offset: float = 60.0

# === 火焰 ===
@export var flame_interval: float = 0.4        # 每团火焰释放间隔
@export var flame_speed: float = 80.0

# === 雷电 ===
@export var thunder_vanish_duration: float = 2.0  # 隐身时长
@export var thunder_count: int = 3
@export var thunder_interval: float = 0.6
@export var thunder_ultimate_cycle: int = 3       # 每几次普通状态触发必杀
```

---

## 四、小怪基类设计

```gdscript
# scripts/enemy/base/BaseEnemy.gd
class_name BaseEnemy
extends CharacterBody2D

# ── 节点引用（子类场景中必须包含这些节点名） ──
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $HurtBox
@onready var hitbox: Area2D = $HitBox           # 身体伤害框

# ── 数据 ──
@export var data: EnemyData

# ── 状态 ──
var is_dead: bool = false
var facing_right: bool = true

func _ready() -> void:
    hurtbox.area_entered.connect(_on_hurtbox_area_entered)

# 受击入口（由玩家 HitBox 调用）
func take_damage(amount: int) -> void:
    if is_dead:
        return
    _die()

func _die() -> void:
    is_dead = true
    hitbox.set_deferred("monitoring", false)
    hitbox.set_deferred("monitorable", false)
    hurtbox.set_deferred("monitoring", false)
    hurtbox.set_deferred("monitorable", false)
    set_physics_process(false)
    anim.play(data.death_anim)
    anim.animation_finished.connect(_on_death_anim_finished, CONNECT_ONE_SHOT)

func _on_death_anim_finished() -> void:
    queue_free()

func _on_hurtbox_area_entered(area: Area2D) -> void:
    # 子类可覆盖；默认不处理（由玩家HitBox主动调用 take_damage）
    pass

# 工具方法：翻转朝向
func _set_facing(right: bool) -> void:
    facing_right = right
    anim.flip_h = not right
```

---

## 五、小怪各类实现要点

### 5.1 地面巡逻怪（PatrolEnemy）

**节点树**
```
PatrolEnemy (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── HurtBox (Area2D)          # 受击框
├── HitBox (Area2D)           # 接触伤害框
├── FloorDetectLeft (RayCast2D)   # 地面边缘检测（左）
├── FloorDetectRight (RayCast2D)  # 地面边缘检测（右）
└── WallDetect (RayCast2D)        # 墙壁检测
```

**核心逻辑**
```gdscript
# PatrolEnemy.gd
class_name PatrolEnemy
extends BaseEnemy

func _physics_process(delta: float) -> void:
    if is_dead: return
    _apply_gravity(delta)
    _check_turn()
    velocity.x = data.move_speed * (1.0 if facing_right else -1.0)
    move_and_slide()

func _check_turn() -> void:
    var edge_ray = floor_detect_right if facing_right else floor_detect_left
    if not edge_ray.is_colliding() or is_on_wall():
        _set_facing(not facing_right)
```

---

### 5.2 蝙蝠（BatEnemy）

**节点树**
```
BatEnemy (Area2D)             # 飞行怪用 Area2D，不需要物理碰撞
├── AnimatedSprite2D
├── CollisionShape2D
└── HitBox (Area2D)
```

> **注意**：蝙蝠用 `Area2D` 而非 `CharacterBody2D`，因为它不需要地面碰撞，
> 继承 `Node2D` 版本的 BaseEnemy 变体（或单独实现）。

**核心逻辑**
```gdscript
# BatEnemy.gd
var _time: float = 0.0
var _start_y: float = 0.0

func _ready() -> void:
    _start_y = global_position.y

func _process(delta: float) -> void:
    if is_dead: return
    _time += delta
    # 单向水平移动 + 正弦波垂直偏移
    var bat_data := data as BatData
    position.x += data.move_speed * delta * (-1.0 if facing_right == false else -1.0)
    position.y = _start_y + sin(_time * bat_data.sine_frequency * TAU) * bat_data.sine_amplitude
    # 飞出屏幕判断（由关卡的 VisibleOnScreenNotifier2D 处理）
```

---

### 5.3 老鹰（EagleEnemy）

**状态枚举（内部简易状态，不用独立FSM）**
```
DIVING   → 俯冲阶段（弧线向玩家）
EXITING  → 飞出屏幕阶段
TURNING  → 减速掉头阶段
```

**核心逻辑**
```gdscript
# EagleEnemy.gd
enum Phase { DIVING, EXITING, TURNING }
var phase: Phase = Phase.DIVING
var _curve_velocity: Vector2 = Vector2.ZERO

func _physics_process(delta: float) -> void:
    match phase:
        Phase.DIVING:  _update_dive(delta)
        Phase.EXITING: _update_exit(delta)
        Phase.TURNING: _update_turn(delta)

func _update_dive(delta: float) -> void:
    # 用 lerp 向玩家方向施加曲线力
    var eagle_data := data as EagleData
    var to_player = (player.global_position - global_position).normalized()
    _curve_velocity = _curve_velocity.lerp(
        to_player * data.move_speed,
        delta * eagle_data.dive_curve_strength * 0.01
    )
    position += _curve_velocity * delta
    # 离开屏幕后切换 EXITING
```

---

### 5.4 飞天忍者（FlyingNinja）

**内部状态**
```
RISING   → 从屏幕下方上升
THROWING → 到达最高点，射出飞镖
FALLING  → 坠落消失
```

**核心逻辑**
```gdscript
func _update_rising(delta: float) -> void:
    position.y -= data.rise_speed * delta
    if position.y <= _peak_y:
        _change_phase(Phase.THROWING)

func _update_throwing() -> void:
    var direction = (player.global_position - global_position).normalized()
    var dart = DART_SCENE.instantiate()
    dart.initialize(direction, ninja_data.dart_data)
    get_parent().add_child(dart)
    dart.global_position = global_position
    _change_phase(Phase.FALLING)
```

---

### 5.5 下蹲扔镖忍者（CrouchNinja）

**节点树**
```
CrouchNinja (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── HurtBox
├── HitBox
├── AttackZone1 (Area2D)   # 攻击区域1（编辑器中手动摆放）
├── AttackZone2 (Area2D)   # 攻击区域2
└── AttackZone3 (Area2D)   # 攻击区域3（可选）
```

**核心逻辑**
```gdscript
var _cooldown_timer: float = 0.0
var _player_in_zone: bool = false

func _physics_process(delta: float) -> void:
    if is_dead: return
    _face_player()           # 每帧朝向玩家
    _update_cooldown(delta)
    if _player_in_zone and _cooldown_timer <= 0.0:
        _throw_dart()
        _cooldown_timer = (data as CrouchNinjaData).attack_cooldown

func _face_player() -> void:
    _set_facing(player.global_position.x > global_position.x)
    # 同步翻转所有 AttackZone 的 scale.x
    for zone in attack_zones:
        zone.scale.x = 1.0 if facing_right else -1.0
```

---

### 5.6 枪手（Gunner）

**内部状态**
```
PATROLLING  → 巡逻
WARNING     → 红色闪烁0.5秒
SHOOTING    → 射出激光
COOLDOWN    → 冷却后回到巡逻
```

**核心逻辑**
```gdscript
func _enter_warning() -> void:
    phase = Phase.WARNING
    _warn_timer = gunner_data.warn_duration
    # 开始红色闪烁（使用 modulate 或 shader）
    _blink_tween = create_tween().set_loops()
    _blink_tween.tween_property(anim, "modulate", Color.RED, 0.1)
    _blink_tween.tween_property(anim, "modulate", Color.WHITE, 0.1)

func _shoot_laser() -> void:
    _blink_tween.kill()
    anim.modulate = Color.WHITE
    var laser = LASER_SCENE.instantiate()
    laser.initialize(Vector2.RIGHT if facing_right else Vector2.LEFT, gunner_data.laser_data)
    get_parent().add_child(laser)
    laser.global_position = global_position + Vector2(16 if facing_right else -16, 0)
```

---

### 5.7 追击拳手忍者（ChaserNinja）

**节点树**
```
ChaserNinja (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── HurtBox
├── HitBox
├── FloorDetectFront (RayCast2D)  # 前方地面检测（检测断崖）
└── WallDetectFront (RayCast2D)   # 前方墙壁检测（检测障碍）
```

**核心逻辑**
```gdscript
var _is_chasing: bool = true
var _jump_cooldown: float = 0.0

func _physics_process(delta: float) -> void:
    if is_dead or not _is_chasing: return
    _apply_gravity(delta)
    _jump_cooldown -= delta

    # 遇到断崖或障碍物 → 跳跃
    if is_on_floor():
        if not _floor_detect_front.is_colliding() or is_on_wall():
            if _jump_cooldown <= 0.0:
                _do_jump()

    # 追踪玩家Y轴跳跃
    if player.velocity.y < -10.0 and is_on_floor() and _jump_cooldown <= 0.0:
        _do_jump()

    velocity.x = chaser_data.chase_speed * (1.0 if facing_right else -1.0)
    move_and_slide()

func _do_jump() -> void:
    velocity.y = chaser_data.jump_force
    _jump_cooldown = 0.3   # 防连跳
```

---

## 六、投射物设计

### 6.1 飞镖（Dart）

```gdscript
# Dart.gd
class_name Dart
extends Area2D

var _direction: Vector2
var _data: DartData
var _hp: int

func initialize(direction: Vector2, dart_data: DartData) -> void:
    _direction = direction.normalized()
    _data = dart_data
    _hp = dart_data.max_hp
    # 旋转精灵朝向飞行方向
    rotation = _direction.angle()

func _process(delta: float) -> void:
    position += _direction * _data.speed * delta

func take_damage(amount: int) -> void:
    _hp -= amount
    if _hp <= 0:
        queue_free()

# 飞出屏幕由 VisibleOnScreenNotifier2D 的 screen_exited 信号处理
func _on_screen_exited() -> void:
    queue_free()
```

### 6.2 激光（Laser）

```gdscript
# Laser.gd
class_name Laser
extends Area2D

# 激光不可摧毁，无 HP
# 使用 Line2D 或 AnimatedSprite2D 渲染光束

func initialize(direction: Vector2, laser_data: LaserData) -> void:
    _direction = direction
    _data = laser_data
    # 激光水平方向，根据方向翻转
    if direction.x < 0:
        scale.x = -1.0

func _process(delta: float) -> void:
    position += _direction * _data.speed * delta

func _on_screen_exited() -> void:
    queue_free()
```

---

## 七、BOSS 架构设计

### 7.1 节点树

```
Boss (CharacterBody2D)
├── AnimatedSprite2D
├── CollisionShape2D
├── HurtBoxBack (Area2D)           # 背面受击框（可受伤）
├── HurtBoxFront (Area2D)          # 正面受击框（免疫，播放音效）
├── BodyHitBox (Area2D)            # 身体接触伤害框
├── AttackHitBox (Area2D)          # 攻击专用框（刺击/挥刀等）
├── BossStateMachine               # 状态机节点
│   ├── BossIdleState
│   ├── BossMoveState
│   ├── BossChargeState
│   ├── BossJumpState
│   ├── BossStabState
│   ├── BossSlashState
│   ├── BossEdgeBladeState
│   ├── BossFlameState
│   ├── BossThunderState
│   └── BossAppearState
└── ShockwaveEffect (GPUParticles2D)  # 落地冲击波粒子
```

### 7.2 Boss 主类

```gdscript
# Boss.gd
class_name Boss
extends CharacterBody2D

@export var data: BossData

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var state_machine: BossStateMachine = $BossStateMachine
@onready var hurt_box_back: Area2D = $HurtBoxBack
@onready var hurt_box_front: Area2D = $HurtBoxFront
@onready var body_hitbox: Area2D = $BodyHitBox
@onready var attack_hitbox: Area2D = $AttackHitBox
@onready var shockwave_effect: GPUParticles2D = $ShockwaveEffect

var current_hp: int
var is_phase2: bool = false
var is_hit_stunned: bool = false
var facing_right: bool = true

# 必杀技计数器
var _normal_state_count: int = 0

# 玩家引用（由关卡注入）
var player: Player

signal phase2_entered
signal boss_defeated

func _ready() -> void:
    current_hp = data.max_hp
    hurt_box_back.area_entered.connect(_on_back_hit)
    hurt_box_front.area_entered.connect(_on_front_hit)

# ── 受伤处理 ──
func take_damage(amount: int) -> void:
    if is_hit_stunned: return
    current_hp -= amount
    _start_hit_stun()
    if current_hp <= 0:
        _die()
        return
    if not is_phase2 and current_hp <= data.max_hp * data.phase2_threshold:
        _enter_phase2()

func _start_hit_stun() -> void:
    is_hit_stunned = true
    anim.modulate = Color.WHITE
    # 使用 Tween 做白色闪烁
    var tween = create_tween()
    tween.tween_interval(data.hit_stun_duration)
    tween.tween_callback(func(): is_hit_stunned = false; anim.modulate = Color.WHITE)

func _enter_phase2() -> void:
    is_phase2 = true
    # 切换铠甲素材（绿→红）：直接在 AnimatedSprite2D 的 SpriteFrames 中
    # 为 phase2 添加独立动画帧集，命名规则加 "_p2" 后缀
    emit_signal("phase2_entered")

func _die() -> void:
    state_machine.enabled = false
    # 播放死亡动画后发送信号
    anim.play("death")
    anim.animation_finished.connect(func(): emit_signal("boss_defeated"), CONNECT_ONE_SHOT)

# ── 正面防御 ──
func _on_front_hit(area: Area2D) -> void:
    AudioManager.play_sound("boss_block")   # 金属防御音效

func _on_back_hit(area: Area2D) -> void:
    take_damage(1)   # 具体伤害由攻击方传入，这里演示固定值

# ── 工具方法 ──
func set_facing(right: bool) -> void:
    facing_right = right
    anim.flip_h = not right

func face_player() -> void:
    set_facing(player.global_position.x > global_position.x)

func emit_shockwave() -> void:
    shockwave_effect.restart()
    shockwave_effect.emitting = true

# ── 必杀技计数 ──
func on_normal_state_finished() -> void:
    _normal_state_count += 1

func should_use_ultimate() -> bool:
    return is_phase2 and (_normal_state_count >= data.thunder_ultimate_cycle)

func reset_ultimate_counter() -> void:
    _normal_state_count = 0
```

### 7.3 BOSS 状态机

```gdscript
# BossStateMachine.gd
class_name BossStateMachine
extends Node

var current_state: BossState
var states: Dictionary = {}
var enabled: bool = true

# 地面限定状态列表
const GROUND_ONLY_STATES = [
    "BossMoveState", "BossChargeState", "BossStabState",
    "BossSlashState", "BossEdgeBladeState", "BossFlameState"
]

@onready var boss: Boss = owner

func _ready() -> void:
    for child in get_children():
        if child is BossState:
            states[child.get_class()] = child
            child.state_machine = self
    # 从显现状态开始
    _enter_state(states["BossAppearState"])

func _physics_update(delta: float) -> void:
    if not enabled or current_state == null: return
    current_state.update(delta)

func change_state(new_state_class: String, msg: Dictionary = {}) -> void:
    if current_state:
        current_state.exit()
    current_state = states[new_state_class]
    current_state.enter(msg)

# 随机选取下一个合理状态
func pick_next_state() -> String:
    # 必杀技优先判断
    if boss.should_use_ultimate():
        boss.reset_ultimate_counter()
        return "BossThunderState"

    var available: Array[String] = []
    var is_on_floor = boss.is_on_floor()

    for state_name in states.keys():
        # 跳过待机、显现、雷电（由特殊逻辑控制）
        if state_name in ["BossIdleState", "BossAppearState", "BossThunderState"]:
            continue
        # 地面限定状态：BOSS必须在地面
        if state_name in GROUND_ONLY_STATES and not is_on_floor:
            continue
        available.append(state_name)

    return available[randi() % available.size()]
```

### 7.4 BOSS 状态基类

```gdscript
# BossState.gd
class_name BossState
extends Node

var state_machine: BossStateMachine
@onready var boss: Boss = owner

func enter(_msg: Dictionary = {}) -> void:
    pass

func update(_delta: float) -> void:
    pass

func exit() -> void:
    pass

# 进入冷却后切换到下一状态（大多数状态结束后调用）
func finish_and_cooldown() -> void:
    boss.on_normal_state_finished()
    state_machine.change_state("BossIdleState", {
        "cooldown": boss.data.state_cooldown_phase2 if boss.is_phase2
                    else boss.data.state_cooldown_normal
    })
```

### 7.5 关键状态实现要点

#### 待机（BossIdleState）
```gdscript
var _timer: float = 0.0
var _cooldown: float = 0.0

func enter(msg: Dictionary) -> void:
    boss.anim.play("idle")
    _cooldown = msg.get("cooldown", 0.0)
    _timer = 0.0

func update(delta: float) -> void:
    _timer += delta
    if _timer >= _cooldown:
        state_machine.change_state(state_machine.pick_next_state())
```

#### 冲撞（BossChargeState）
```gdscript
# 穿过玩家，撞墙回待机
func enter(_msg: Dictionary) -> void:
    boss.face_player()
    boss.anim.play("charge")
    # 攻击框开启
    boss.attack_hitbox.set_deferred("monitoring", true)

func update(delta: float) -> void:
    boss.velocity.x = boss.data.charge_speed * (1.0 if boss.facing_right else -1.0)
    boss.move_and_slide()
    if boss.is_on_wall():
        _end_charge()

func exit() -> void:
    boss.attack_hitbox.set_deferred("monitoring", false)
    boss.velocity.x = 0.0

func _end_charge() -> void:
    finish_and_cooldown()
```

#### 跳跃（BossJumpState）
```gdscript
enum JumpPhase { CROUCHING, AIRBORNE, LANDING }
var _phase: JumpPhase
var _crouch_timer: float

func enter(_msg: Dictionary) -> void:
    _phase = JumpPhase.CROUCHING
    _crouch_timer = boss.data.jump_crouch_duration
    boss.anim.play("jump_crouch")

func update(delta: float) -> void:
    match _phase:
        JumpPhase.CROUCHING:
            _crouch_timer -= delta
            if _crouch_timer <= 0.0:
                boss.velocity.y = boss.data.jump_force
                # 水平朝向玩家
                var dx = boss.player.global_position.x - boss.global_position.x
                boss.velocity.x = clamp(dx * 2.0, -200.0, 200.0)
                boss.anim.play("jump_rise")
                _phase = JumpPhase.AIRBORNE

        JumpPhase.AIRBORNE:
            boss.move_and_slide()
            if boss.is_on_floor():
                _phase = JumpPhase.LANDING
                boss.emit_shockwave()
                boss.anim.play("jump_land")
                await boss.anim.animation_finished
                finish_and_cooldown()
```

#### 雷电必杀（BossThunderState）
```gdscript
const THUNDER_SCENE = preload("res://scenes/projectile/thunder.tscn")

func enter(_msg: Dictionary) -> void:
    boss.anim.play("thunder_jump")
    # 飞到空中（直接设置Y位置或用Tween）
    var tween = boss.create_tween()
    tween.tween_property(boss, "position:y", boss.position.y - 120.0, 0.4)
    tween.tween_callback(_start_vanish)

func _start_vanish() -> void:
    boss.anim.play("thunder_vanish")
    var tween = boss.create_tween()
    # 逐渐隐身：modulate.a 从 1 → 0
    tween.tween_property(boss, "modulate:a", 0.0, boss.data.thunder_vanish_duration)
    tween.tween_callback(_start_thunder_sequence)

func _start_thunder_sequence() -> void:
    # 连续召唤3次雷电
    _spawn_thunder_sequence(boss.data.thunder_count)

func _spawn_thunder_sequence(remaining: int) -> void:
    if remaining <= 0:
        _end_ultimate()
        return
    var thunder = THUNDER_SCENE.instantiate()
    get_tree().current_scene.add_child(thunder)
    thunder.global_position = Vector2(boss.player.global_position.x, -50)  # 从屏幕上方落下
    thunder.damage = boss.data.ultimate_damage
    await get_tree().create_timer(boss.data.thunder_interval).timeout
    _spawn_thunder_sequence(remaining - 1)

func _end_ultimate() -> void:
    # 在画面边缘随机显现
    state_machine.change_state("BossAppearState")
```

#### 显现（BossAppearState）
```gdscript
func enter(_msg: Dictionary) -> void:
    # 随机左右边缘
    var screen_width = 480.0  # 项目分辨率宽
    var x = 8.0 if randf() < 0.5 else screen_width - 8.0
    boss.global_position.x = x
    boss.modulate.a = 0.0
    boss.anim.play("appear")
    var tween = boss.create_tween()
    tween.tween_property(boss, "modulate:a", 1.0, 0.6)
    tween.tween_callback(func(): state_machine.change_state("BossIdleState"))
```

---

## 八、雷电场景设计

```gdscript
# Thunder.gd
class_name Thunder
extends Area2D

# 3帧动画：从画面上方落下
var damage: int = 3

func _ready() -> void:
    $AnimatedSprite2D.play("strike")
    $AnimatedSprite2D.animation_finished.connect(queue_free)

# 伤害由 area_entered 处理（Player的HurtBox进入时触发）
```

---

## 九、关键约定（给 AI 的提示）

以下约定确保 AI 生成代码时不产生歧义：

| 约定 | 说明 |
|------|------|
| 玩家引用注入 | 所有敌人/BOSS通过 `player` 变量引用玩家，由关卡的 `_ready()` 注入，不使用 `get_node` 硬路径 |
| 投射物生成 | 所有投射物通过 `get_parent().add_child()` 添加到关卡根节点，不作为敌人子节点 |
| 死亡清理 | 死亡时先禁用所有碰撞框，播放动画，动画结束后 `queue_free()` |
| 状态切换 | BOSS状态切换统一走 `state_machine.change_state(class_name_string)` |
| 数值来源 | 所有数值从 `data` Resource 读取，禁止在逻辑代码中出现魔数 |
| 屏幕边界 | 飞行类/单向移动怪统一挂载 `VisibleOnScreenNotifier2D`，`screen_exited` 信号触发 `queue_free()` |
| 信号命名 | 统一用 `_on_` 前缀连接信号回调 |
| Phase2 动画 | BOSS强化模式动画统一以 `_p2` 后缀区分（如 `idle_p2`、`charge_p2`） |

---

## 十、开发顺序建议

```
阶段1（基础）
  └─ BaseEnemy + 死亡系统 + 飞镖场景
      → 地面巡逻怪（验证基类）

阶段2（飞行 & 投射）
  └─ 蝙蝠 → 老鹰 → 飞天忍者
      → 建立 VisibleOnScreenNotifier2D 屏幕边界方案

阶段3（忍者系列）
  └─ 攀墙忍者 → 下蹲扔镖 → 移动扔镖 → 枪手 → 追击拳手

阶段4（BOSS框架）
  └─ BossData + Boss主类 + 状态机骨架
      → 待机 → 移动 → 冲撞（验证FSM）

阶段5（BOSS攻击状态）
  └─ 跳跃（含冲击波）→ 刺击 → 挥刀 → 棱刃 → 火焰

阶段6（BOSS必杀 & 强化）
  └─ 雷电必杀 → 显现 → Phase2切换逻辑

阶段7（收尾）
  └─ 音效接入 + 数值调试 + 关卡摆放
```
