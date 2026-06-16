# ============================================================
# 文件：autoload/AudioManager.gd
# 作用：全局音频播放器，负责把 SoundRegistry 查到的声音放出来
# ============================================================
extends Node

# 专门放背景音乐的播放器
var _bgm_player: AudioStreamPlayer

# 专门放音效的播放器池（准备8个，动作游戏音效密集，4个不够用）
var _sfx_players: Array[AudioStreamPlayer] = []
const SFX_POOL_SIZE = 8

func _ready() -> void:
	# 暂停时音频必须独立于 time_scale 运行，否则暂停音效播不出来
	process_mode = PROCESS_MODE_ALWAYS

	# 1. 初始化 BGM 播放器
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.process_mode = PROCESS_MODE_ALWAYS
	add_child(_bgm_player)

	# 2. 初始化 SFX 音效播放器池
	for i in range(SFX_POOL_SIZE):
		var player = AudioStreamPlayer.new()
		player.process_mode = PROCESS_MODE_ALWAYS
		add_child(player)
		_sfx_players.append(player)
		

## 全局统一播放接口：不管是BGM还是斩击音效，统统调用这个方法！
func play_sound(event_id: StringName) -> void:
	# 去前台大姐（SoundRegistry）那里查花名册
	var event: SoundEventResource = SoundRegistry.get_event(event_id)
	
	# 如果查不到，打印一个警告，防止游戏崩溃
	if event == null:
		print("【音频系统警告】找不到事件 ID: ", event_id)
		return
		
	# 根据身份证上的类型，决定怎么播放
	if event.bus == "BGM":
		_play_bgm(event)
	else:
		_play_sfx(event)

# 内部私有方法：处理背景音乐
func _play_bgm(event: SoundEventResource) -> void:
	# 如果当前已经在放这首歌了，就不要从头重播了
	if _bgm_player.stream == event.stream and _bgm_player.playing:
		return
		
	_bgm_player.stream = event.stream
	_bgm_player.volume_db = event.volume_db
	_bgm_player.pitch_scale = event.pitch
	_bgm_player.bus = event.bus
	_bgm_player.play()
	print("【音频系统】正在播放背景音乐: ", event.event_id)

# ── 暂停/恢复 BGM（供暂停界面调用） ──
func pause_bgm() -> void:
	if _bgm_player.playing:
		_bgm_player.stream_paused = true

func resume_bgm() -> void:
	_bgm_player.stream_paused = false

# 内部私有方法：处理动作音效
func _play_sfx(event: SoundEventResource) -> void:
	# 寻找一个当前没有在唱歌（空闲）的收音机
	var target_player: AudioStreamPlayer = null
	for player in _sfx_players:
		if not player.playing:
			target_player = player
			break
			
	# 如果大家都挺忙的，就强行征用第一个（先 stop 确保音频服务器重置）
	if target_player == null:
		target_player = _sfx_players[0]
		target_player.stop()
		
	# 计算随机音调（让每次挥刀声音有细微不同，Claude 推荐的高级货）
	var final_pitch = event.pitch
	if event.pitch_variance > 0.0:
		final_pitch += randf_range(-event.pitch_variance, event.pitch_variance)
		
	# 把身份证上的属性赋予播放器
	target_player.stream = event.stream
	target_player.volume_db = event.volume_db
	target_player.pitch_scale = final_pitch
	target_player.bus = event.bus
	target_player.play()
