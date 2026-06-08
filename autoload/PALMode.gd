# PALMode.gd - 全局 PAL 模式控制
extends Node

var pal_mode: bool = true   # 默认开启 PAL 慢速模式

func _ready():
	if pal_mode:
		Engine.time_scale = 0.833   # 83.3% 速度
