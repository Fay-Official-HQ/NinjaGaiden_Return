extends BossAIComponent
class_name BossAIComponent_2

const DECISION_COOLDOWN: float = 2.0

func _ready() -> void:
	_decision_timer = DECISION_COOLDOWN

func _process(delta: float) -> void:
	if boss.is_dead:
		return

	_decision_timer -= delta
	if _decision_timer <= 0.0:
		_decision_timer = DECISION_COOLDOWN
		_make_decision()


func _make_decision() -> void:
	if not boss.player_ref:
		_pending_action = ""
		return

	if randf() < 0.5:
		_pending_action = "BossFlyState"
	else:
		_pending_action = "BossFireballState"
