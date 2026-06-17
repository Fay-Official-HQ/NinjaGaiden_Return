extends Node

## 关卡入口点名（切场景前设置，关卡加载后玩家自动传送到对应 Marker2D）
static var spawn_point: String = "default"


#切换关卡使用方法
#1.关卡根节点下新建entry_right、entry_left子节点（Marker2D）
#2.关卡根节点下新建TransitionZoneR类型节点
#3.给每个TransitionZoneR类型节点设置target_scene（场景字符串路径）、spawn_point（值为entry_right、entry_left）
#注意：一定要有一个玩家默认位置，且锁定，因为死亡重开就是这个默认位置！

## 统一的关卡切换入口
## 特点：
##   1. call_deferred 延迟执行，彻底避免物理回调冲突
##   2. 不处理任何淡入淡出——让每个关卡自己在 _ready 中实现（如有需要）
##   3. 切换前自动保存入口点，目标关卡加载后 _place_player_at_entry 会读取
static func goto_level(scene_path: String, entry_point: String = "default") -> void:
	spawn_point = entry_point
	(Engine.get_main_loop() as SceneTree).call_deferred("change_scene_to_file", scene_path)
