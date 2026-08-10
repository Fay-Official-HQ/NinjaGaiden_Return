extends Node2D

# ════════════════════════════════════════════════════════════
#  Current 场景控制器 —— 点阵电流动画
#  让场景下所有直接子级 AnimatedSprite2D（zuo / zhong / you，
#  若复制多个 zhong 也自动包含）同步播放，帧进度保持一致。
# ════════════════════════════════════════════════════════════

## 收集到的动画精灵列表
var _sprites: Array[AnimatedSprite2D] = []


func _ready() -> void:
	# 收集所有直接子级的 AnimatedSprite2D（zuo、zhong、you……自动全包含），
	# 并统一强制播放 default 动画（不依赖场景里的 autoplay 勾选，
	# 否则后添加的 zhong2/zhong3 等若没勾 autoplay 就不会动）
	for child in get_children():
		if child is AnimatedSprite2D:
			child.play("default")
			_sprites.append(child)


func _process(_delta: float) -> void:
	if _sprites.is_empty():
		return
	# 以第一个精灵为基准，其余精灵每帧强制跟随其帧与帧进度，保证完全同步
	var base: AnimatedSprite2D = _sprites[0]
	for i in range(1, _sprites.size()):
		var sprite: AnimatedSprite2D = _sprites[i]
		sprite.frame = base.frame
		sprite.frame_progress = base.frame_progress
