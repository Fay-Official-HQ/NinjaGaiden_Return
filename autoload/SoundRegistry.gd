extends Node

var _registry: Dictionary = {}

var _audio_files: Array[String] = [
	# BGM
	"res://resources/audio/bgm/bgml1.tres",
	"res://resources/audio/bgm/wind1.tres",
	"res://resources/audio/bgm/zhandou1.tres",
	"res://resources/audio/bgm/zhandou2.tres",
	"res://resources/audio/bgm/zhandou3.tres",
	"res://resources/audio/bgm/bgm2_1.tres",
	"res://resources/audio/bgm/bgm2_2.tres",
	"res://resources/audio/bgm/bgm3_1.tres",
	"res://resources/audio/bgm/bgm4_1.tres",
	"res://resources/audio/bgm/bgm4_2.tres",
	"res://resources/audio/bgm/bgm5_1.tres",
	"res://resources/audio/bgm/bgm6_1.tres",
	"res://resources/audio/bgm/bgm7_1.tres",
	"res://resources/audio/bgm/bgm7_2.tres",
	"res://resources/audio/bgm/bgm7_3.tres",
	"res://resources/audio/bgm/dark_aura_1.tres",
	"res://resources/audio/bgm/dark_aura_2.tres",
	"res://resources/audio/bgm/end_good.tres",
	"res://resources/audio/bgm/end_bad.tres",
	# 玩家音效
	"res://resources/audio/player/bishaji.tres",
	"res://resources/audio/player/gongji.tres",
	"res://resources/audio/player/hanjiao.tres",
	"res://resources/audio/player/HPhuifu.tres",
	"res://resources/audio/player/jianqianchong.tres",
	"res://resources/audio/player/jianshangtiao.tres",
	"res://resources/audio/player/jianxiapi.tres",
	"res://resources/audio/player/jianxuanzhuan.tres",
	"res://resources/audio/player/rendahuifu.tres",
	"res://resources/audio/player/renhuifu.tres",
	"res://resources/audio/player/renshubiao.tres",
	"res://resources/audio/player/renshuhuoyan.tres",
	"res://resources/audio/player/renshuhuoqiu.tres",
	"res://resources/audio/player/renshulengren.tres",
	"res://resources/audio/player/shoushang.tres",
	"res://resources/audio/player/siwang.tres",
	"res://resources/audio/player/tiaoyue.tres",
	"res://resources/audio/player/yinshen.tres",
	# 音效
	"res://resources/audio/se/disiwang.tres",
	"res://resources/audio/se/disiwang2.tres",
	"res://resources/audio/se/rengbiao.tres",
	"res://resources/audio/se/jiguang.tres",
	"res://resources/audio/se/bosssiwang.tres",
	"res://resources/audio/se/leidian.tres",
	"res://resources/audio/se/shibingfashe.tres",
	"res://resources/audio/se/shibingxuli.tres",
	"res://resources/audio/se/chujue.tres",
	"res://resources/audio/se/dingling.tres",
	"res://resources/audio/se/fangyu.tres",
	"res://resources/audio/se/zanting.tres",
]

var _pending_paths: Array[String] = []

func _ready() -> void:
	for path in _audio_files:
		ResourceLoader.load_threaded_request(path, "", true, ResourceLoader.CACHE_MODE_REPLACE)
		_pending_paths.append(path)

func _process(_delta: float) -> void:
	var i = 0
	while i < _pending_paths.size():
		var path = _pending_paths[i]
		match ResourceLoader.load_threaded_get_status(path):
			ResourceLoader.THREAD_LOAD_LOADED:
				var res = ResourceLoader.load_threaded_get(path) as SoundEventResource
				if res and res.event_id != "":
					_registry[res.event_id] = res
					print("【音频系统】登记声音: ", res.event_id)
				_pending_paths.remove_at(i)
			ResourceLoader.THREAD_LOAD_FAILED:
				print("【音频系统】加载失败: ", path)
				_pending_paths.remove_at(i)
			_:
				i += 1

func get_event(event_id: StringName) -> SoundEventResource:
	if _registry.has(event_id):
		return _registry[event_id]
	# 后台还没加载完时，按需同步回退
	var i = 0
	while i < _pending_paths.size():
		var path = _pending_paths[i]
		var res = load(path) as SoundEventResource
		if res and res.event_id == event_id:
			_registry[event_id] = res
			_pending_paths.remove_at(i)
			return res
		i += 1
	return null
