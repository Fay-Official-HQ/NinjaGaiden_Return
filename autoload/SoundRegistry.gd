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

func _ready() -> void:
	for path in _audio_files:
		var res := load(path) as SoundEventResource
		if res and res.event_id != "":
			_registry[res.event_id] = res
			print("【音频系统】成功登记声音：" + str(res.event_id))

func get_event(event_id: StringName) -> SoundEventResource:
	return _registry.get(event_id, null)
