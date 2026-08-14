extends Node2D
class_name BossGlass

## 玻璃罩破碎后要生成的 BOSS 场景（稍后制作，在 Inspector 中拖入）
@export var boss_scene: PackedScene

## 玻璃罩被击碎信号：发出破碎时的世界坐标（供关卡脚本监听）
signal statue_destroyed(spawn_position: Vector2)

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
## 可选受击框：场景中若存在 HurtBox 会自动连接，受击即破碎
@onready var hurt_box: HurtBox = get_node_or_null("HurtBox")

var _is_broken := false


func _ready() -> void:
	if hurt_box:
		hurt_box.took_damage.connect(_on_took_damage)
	animated_sprite.play("default")


## 播放死亡动画接口：击碎玻璃罩并生成 BOSS（受击或外部调用均可触发）
func break_glass() -> void:
	if _is_broken:
		return
	_is_broken = true
	AudioManager.play_sound(&"disiwang")
	animated_sprite.play("death")
	await animated_sprite.animation_finished
	# 玻璃罩破碎后不会消失：一直保持死亡状态动画
	animated_sprite.play("isdead")
	_spawn_boss()
	statue_destroyed.emit(global_position)


func _on_took_damage(_damage: int, _is_heavy: bool) -> void:
	break_glass()


## 在玻璃罩位置生成 BOSS（若已配置 boss_scene）
func _spawn_boss() -> void:
	if boss_scene == null:
		return
	var boss: Node2D = boss_scene.instantiate()
	boss.global_position = global_position
	get_tree().current_scene.add_child(boss)
