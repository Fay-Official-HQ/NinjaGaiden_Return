# ============================================================
# 文件：autoload/SoundRegistry.gd
# 作用：游戏启动时，自动扫描并登记所有音频身份证（.tres）
# ============================================================
extends Node

# 用一个字典（总花名册）来存所有声音：{ "bgm_test": 身份证资源 }
var _registry: Dictionary = {}

func _ready() -> void:
	# 游戏一启动，就去下面这几个文件夹里搜寻身份证
	_load_from_dir("res://resources/audio/bgm/")
	_load_from_dir("res://resources/audio/player/")
	_load_from_dir("res://resources/audio/se/")

func _load_from_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	# 如果文件夹不存在（比如我们还没建 enemy 文件夹），就直接跳过，绝对不报错
	if dir == null:
		return
		
	dir.list_dir_begin()
	var fname := dir.get_next()
	
	while fname != "":
		# 如果发现是一个 .tres 结尾的配置文件
		if fname.ends_with(".tres"):
			var res := load(path + fname) as SoundEventResource
			# 只要这个配置文件里填了唯一 ID，就把它登记到名册里
			if res and res.event_id != "":
				_registry[res.event_id] = res
				# 在控制台打印出来，方便我们菜鸟排查 Bug
				print("【音频系统】成功登记声音：" + str(res.event_id))
		fname = dir.get_next()

## 提供给其他脚本的查询接口：拿名字换身份证
func get_event(event_id: StringName) -> SoundEventResource:
	return _registry.get(event_id, null)
