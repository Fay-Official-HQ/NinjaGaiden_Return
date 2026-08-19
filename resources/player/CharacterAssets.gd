# res://resources/player/CharacterAssets.gd
# ============================================================
# 角色专属素材配置（每个角色一份 .tres）
# 作用：让共用一套代码的多个角色（Ryu / ChangFei...），使用各自独立的
#       必杀技/处决特效贴图，以及各自专属的音效。
# 用法：
#   1. 新建 res://resources/player/CharacterAssets_XXX.tres
#   2. 在 Inspector 中替换 shadow_textures / final_phantom_texture / sound_overrides
#   3. 把该 tres 拖到角色场景根节点 Player 的 assets 属性上
#   4. 未设置 assets 的角色（旧角色 Ryu）自动使用本脚本默认值（Ryu 素材），无需改动
# ============================================================
extends Resource
class_name CharacterAssets

# 必杀技（真龍閃華）与处决（灭杀连斩）使用的 5 张残影/幻影贴图
@export var shadow_textures: Array = [
	preload("res://assets/sprites/ChangFei/shadows/ChangFei66.png"),
	preload("res://assets/sprites/ChangFei/shadows/ChangFei67.png"),
	preload("res://assets/sprites/ChangFei/shadows/ChangFei68.png"),
	preload("res://assets/sprites/ChangFei/shadows/ChangFei69.png"),
	preload("res://assets/sprites/ChangFei/shadows/ChangFei70.png")
]

# 必杀技最后一击的大刀幻影贴图
@export var final_phantom_texture: Texture2D = preload("res://assets/sprites/ChangFei/ChangFei64.png")

# 音效覆盖表：key = 默认音效 ID（如 "cuoa"），value = 该角色专属音效 ID
# 未来新角色换音效的步骤（不用改代码）：
#   1. 在 resources/audio/ 下新建 SoundEventResource .tres（event_id 取新名字，如 "cf_cuoa"）
#   2. 把路径加进 autoload/SoundRegistry.gd 的 _audio_files 数组
#   3. 在该角色 CharacterAssets_XXX.tres 的 sound_overrides 里加一条 "cuoa": "cf_cuoa"
@export var sound_overrides: Dictionary = {}
