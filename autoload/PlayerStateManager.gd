extends Node

# 玩家状态持久化：跨小关卡保持 HP / MP / TP
# 在章节通关（击败 BOSS）后调用 reset() 恢复默认值

var hp: int = 0
var mp: int = 0
var tp: int = 0

var _initialized: bool = false


## 保存当前玩家数值
func save(player: Player) -> void:
	hp = player.current_hp
	mp = player.ninjutsu.current_mp
	tp = player.sword.current_tp
	_initialized = true


## 恢复到玩家身上（在 Player._ready() 末尾调用）
func apply(player: Player) -> void:
	if not _initialized:
		return
	player.current_hp = hp
	player.ninjutsu.current_mp = mp
	player.sword.current_tp = tp
	player.sword.tp_changed.emit(tp)
	player.ninjutsu.mp_changed.emit(mp)


## 重置为玩家 data 中的初始值（通关 BOSS 后调用）
func reset(player: Player) -> void:
	hp = player.data.initial_hp
	mp = player.data.initial_mp
	tp = player.data.initial_tp
	_initialized = true


## 强制清空存档（重置关卡时调用）
func clear() -> void:
	hp = 0
	mp = 0
	tp = 0
	_initialized = false
