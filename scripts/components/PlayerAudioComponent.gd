# ============================================================
# 文件：scripts/player/PlayerAudioComponent.gd
# 作用：主角专属音频组件，负责监听动画帧和状态机的即时呼叫
# ============================================================
class_name PlayerAudioComponent
extends Node

# 自动绑定主角的动画节点（如果你的叫别名字，请改成对应的名字）
@onready var sprite: AnimatedSprite2D =$"../../Visual/AnimatedSprite2D"

## 核心名册：在这里配置【哪个动画】的【第几帧（从0开始数）】播放【什么声音】
## 以后增加新动画音效，让 AI 帮你往这个字典里添字即可！
const FRAME_SOUNDS: Dictionary = {
	"attack": {
		1: &"gongji" # 代表 "attack" 动画的第 2 帧（索引为1），播放 "gongji"
	},
	 "crouch_attack": {
		1: &"gongji" 
	},
	"air_attack": {
		1: &"gongji" 
	}
	#"test": {
		#0: &"p_footstep", # 示范：跑步动画的第 1 帧和第 3 帧播脚步声
		#2: &"p_footstep"
	#}
}

func _ready() -> void:
	# 核心安全检查：确保动画节点存在
	if sprite:
		# 用代码自动连接信号，这样你就不用去编辑器里手动连了！更安全！
		sprite.frame_changed.connect(_on_sprite_frame_changed)
	else:
		print("【音频组件警告】找不到 AnimatedSprite2D 节点！")

## 接口1：处理【帧同步音效】（全自动查表）
func _on_sprite_frame_changed() -> void:
	var current_anim = sprite.animation
	var current_frame = sprite.frame
	
	# 检查名册里有没有登记当前这个动画
	if FRAME_SOUNDS.has(current_anim):
		var anim_table: Dictionary = FRAME_SOUNDS[current_anim]
		# 检查当前这一帧有没有登记音效
		if anim_table.has(current_frame):
			var sound_id = anim_table[current_frame]
			# 查到了！立刻放音
			AudioManager.play_sound(sound_id)
			print("【组件触发】动画: ", current_anim, " 第 ", current_frame + 1, " 帧，播放音效: ", sound_id)

## 接口2：提供给状态机（FSM）的【即时播放接口】
## 比如跳跃、受伤、忍术出手时，状态机直接调用这个方法
func play_immediate(sound_id: StringName) -> void:
	AudioManager.play_sound(sound_id)
	print("【组件触发】状态机即时呼叫播放音效: ", sound_id)
