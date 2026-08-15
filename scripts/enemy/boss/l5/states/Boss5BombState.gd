extends BossState
class_name Boss5BombState

## 覆盖式轰炸（远程导弹协助）状态
## Boss 只播放一次 hongzha 召唤动画，播完立刻回到飞行继续正常活动；
## 导弹由独立的 BombSpawner 在关卡 hongzha 节点的 Marker 范围内持续生成。
const MISSILE_SCENE: PackedScene = preload("res://scenes/enemy/boss/l5/bomb_missile.tscn")

## Boss 播放召唤动画的时长（秒），播完即可飞行/攻击，不被锁死
var _summon_time: float = 1.5
## 导弹生成间隔（秒）
var _spawn_interval: float = 0.3
## 轰炸总持续时间（秒）
var _duration: float = 5.0
## 导弹下落速度（像素/秒）
var _missile_speed: float = 500.0
## 导弹爆炸伤害
var _missile_damage: int = 3

var _timer: float = 0.0


func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	# 召唤轰炸期间无敌（播 hongzha 召唤动画时玩家无法打断）
	boss.is_invincible = true
	var data := boss.data as BossData_5
	if data:
		_summon_time = data.bomb_summon_time
		_spawn_interval = data.bomb_spawn_interval
		_duration = data.bomb_duration
		_missile_speed = data.bomb_missile_speed
		_missile_damage = data.bomb_missile_damage
	_timer = 0.0
	# 静止播放召唤动画 + 召唤音效
	boss.animated_sprite.play("hongzha")
	_play_summon_sound()
	# 面向玩家
	if boss.player_ref:
		var player_dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(player_dir)
	# 启动独立生成器（Boss 切走后它继续落弹）
	_spawn_spawner()


func update(delta: float) -> void:
	_timer += delta
	# 召唤动画播完即可自由活动，导弹由 BombSpawner 后台持续生成
	if _timer >= _summon_time:
		state_machine.change_state_by_name("BossFlyState")


func exit() -> void:
	# 召唤动画播完退出轰炸状态 → 解除无敌
	boss.is_invincible = false


## 播放召唤音效：用专属独立播放器（不经过 AudioManager 公共 SFX 池）。
## 轰炸期间音效密集（导弹爆炸 leidian、玩家攻击等），公共池只有 8 个，
## 池满时 AudioManager 会强停第一个播放器征用，导致 fangkong 播到一半被截断。
## 独立播放器不占池、不会被征用，播放完自动释放。
func _play_summon_sound() -> void:
	var event: SoundEventResource = SoundRegistry.get_event(&"fangkong")
	if event == null or event.stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.process_mode = PROCESS_MODE_ALWAYS
	player.stream = event.stream
	player.volume_db = event.volume_db
	player.pitch_scale = event.pitch
	player.bus = event.bus
	player.finished.connect(player.queue_free)
	boss.add_child(player)
	player.play()


## 创建 BombSpawner，范围取关卡 hongzha 节点下的 Marker2D1 / Marker2D2
func _spawn_spawner() -> void:
	var root := get_tree().current_scene
	if not root:
		return
	var hongzha_node := root.get_node_or_null("hongzha")
	if not hongzha_node:
		return
	var m1 := hongzha_node.get_node_or_null("Marker2D1")
	var m2 := hongzha_node.get_node_or_null("Marker2D2")
	if not m1 or not m2:
		return
	var spawner := BombSpawner.new()
	spawner.missile_scene = MISSILE_SCENE
	spawner.range_a = m1.global_position
	spawner.range_b = m2.global_position
	spawner.interval = _spawn_interval
	spawner.duration = _duration
	spawner.missile_speed = _missile_speed
	spawner.missile_damage = _missile_damage
	root.add_child(spawner)
