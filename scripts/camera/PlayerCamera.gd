extends Camera2D

class_name PlayerCamera

@export var lock_y: bool = true
@export var fixed_y: float = 0.0

func _ready() -> void:
	top_level = true
	if fixed_y == 0.0:
		var parent = get_parent()
		if parent:
			fixed_y = parent.global_position.y + position.y

func _physics_process(_delta: float) -> void:
	var target = get_parent()
	if not target:
		return
	global_position.x = target.global_position.x
	if lock_y:
		global_position.y = fixed_y
	else:
		global_position.y = target.global_position.y
