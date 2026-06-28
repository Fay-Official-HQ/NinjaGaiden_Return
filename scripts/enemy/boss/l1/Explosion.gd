extends GPUParticles2D
class_name Explosion

func _ready():
	await get_tree().create_timer(lifetime + 0.5).timeout
	queue_free()
