extends BossState
class_name BossSlashState

var hit_box: Area2D
var hit_enemies: Array[HurtBox] = []
var _slash_finished: bool = false

func enter(_msg: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	_face_player()
	boss.animated_sprite.play("attack")
	hit_enemies.clear()
	_slash_finished = false
	var node = boss.get_node_or_null("AttackRoot/SlashHitBox")
	if node:
		hit_box = node as Area2D

func update(_delta: float) -> void:
	var sprite = boss.animated_sprite
	if hit_box and not hit_box.monitoring and sprite.animation == "attack" and sprite.frame >= 1:
		hit_box.set_deferred("monitoring", true)
	if hit_box and hit_box.monitoring:
		var areas = hit_box.get_overlapping_areas()
		for area in areas:
			if area is HurtBox and not hit_enemies.has(area) and area != boss.hurt_box:
				hit_enemies.append(area)
				area.take_damage(boss.data.slash_damage)
	if sprite.animation == "attack" and not sprite.is_playing():
		_slash_finished = true

func physics_update(_delta: float) -> void:
	if _slash_finished:
		_cleanup()
		state_machine.change_state_by_name("BossIdleState")

func exit() -> void:
	_cleanup()

func _cleanup() -> void:
	if hit_box:
		hit_box.set_deferred("monitoring", false)
	hit_enemies.clear()

func _face_player() -> void:
	if boss.player_ref:
		var dir = 1.0 if boss.player_ref.global_position.x > boss.global_position.x else -1.0
		boss.set_facing_direction(dir)
