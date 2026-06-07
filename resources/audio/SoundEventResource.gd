# ============================================================
# 文件：resources/audio/SoundEventResource.gd
# 作用：单条音频事件的数据定义，在编辑器中填写，导出为 .tres
# ============================================================
class_name SoundEventResource
extends Resource

## 唯一事件ID，与状态机/动画中使用的字符串对应（例如 "atk_slash_1"）
@export var event_id: StringName = ""

## 音频流文件（把你的 .mp3 或 .wav 拖到这里）
@export var stream: AudioStream

## 目标总线："SFX"（音效） 或 "BGM"（背景音乐）
@export_enum("SFX", "BGM") var bus: String = "SFX"

## 基础音量（分贝，0是默认，负数是变小声，正数是变大声）
@export_range(-40.0, 6.0) var volume_db: float = 0.0

## 基础音调（1.0是原声，0.5是低沉慢速，2.0是尖锐快速）
@export_range(0.5, 2.0) var pitch: float = 1.0

## 随机音调偏移范围（让每次挥剑的声音有微妙的粗细变化，防止耳朵疲劳）
@export_range(0.0, 0.3) var pitch_variance: float = 0.05

## 最小触发间隔（秒），防止同一帧内因为多次碰撞触发好几次，产生刺耳爆音
@export_range(0.0, 1.0) var cooldown: float = 0.05

## 2D 空间衰减最大距离（0 = 全局播放，比如BGM；如果给小兵用，可以设为400，离得远就听不到）
@export var max_distance: float = 0.0
