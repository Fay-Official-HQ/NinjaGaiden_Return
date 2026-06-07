extends Node
class_name SwordComponent

const MAX_TP = 16
#剑术冷却
const COOLDOWN_TIME = 5.0
#必杀技冷却
const FINISH_COOLDOWN_TIME = 10.0
#剑术消耗
const SWORD_TP_COST = 2
const BUFFER_TIMEOUT = 0.3

var current_tp: int = MAX_TP
var cooldowns: Dictionary = {
	"dash": 0.0,
	"uppercut": 0.0,
	"downslash": 0.0,
	"spin": 0.0,
	"finish": 0.0
}
var input_buffer: Dictionary = {}

signal tp_changed(current_tp: int)

func _ready() -> void:
	current_tp = MAX_TP
	tp_changed.emit(current_tp)
	print("【剑术】组件初始化，当前 TP:", current_tp)

func _process(delta: float) -> void:
	for key in cooldowns.keys():
		cooldowns[key] = max(cooldowns[key] - delta, 0.0)

func can_use(amount: int = SWORD_TP_COST) -> bool:
	return current_tp >= amount

func consume_tp(amount: int = SWORD_TP_COST) -> bool:
	if current_tp >= amount:
		current_tp -= amount
		tp_changed.emit(current_tp)
		print("【剑术】消耗 TP:", amount, "  剩余 TP:", current_tp)
		return true
	print("【剑术】TP 不足！需要:", amount, "  当前:", current_tp)
	return false

func add_tp(amount: int) -> void:
	current_tp = clampi(current_tp + amount, 0, MAX_TP)
	tp_changed.emit(current_tp)

func is_on_cooldown(skill_name: String) -> bool:
	return cooldowns.get(skill_name, 0.0) > 0.0

func start_cooldown(skill_name: String) -> void:
	var cd_time = FINISH_COOLDOWN_TIME if skill_name == "finish" else COOLDOWN_TIME
	cooldowns[skill_name] = cd_time

func get_cooldown_remaining(skill_name: String) -> float:
	return cooldowns.get(skill_name, 0.0)

func buffer_input(skill_name: String) -> void:
	input_buffer[skill_name] = Time.get_ticks_msec()

func has_buffered_input(skill_name: String) -> bool:
	if not input_buffer.has(skill_name):
		return false
	var elapsed = (Time.get_ticks_msec() - input_buffer[skill_name]) / 1000.0
	if elapsed > BUFFER_TIMEOUT:
		input_buffer.erase(skill_name)
		return false
	return true

func consume_buffered_input(skill_name: String) -> void:
	input_buffer.erase(skill_name)

func clear_buffer() -> void:
	input_buffer.clear()
