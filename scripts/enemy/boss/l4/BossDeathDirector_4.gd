extends BossDeathDirector
class_name BossDeathDirector_4

## 第四关 BOSS 死亡导演
## 与 BossDeathDirector 基类流程一致（红黑剪影定格 → 横斩 → 死亡动画 → 黑屏 → 下一章）
## 差异：BOSS4 由骷髅头 + 女人身体两个动画组成，死亡剪影需要同时显示两者

# 骷髅头的定格帧数据（女人身体由基类 _capture_freeze_frame 捕获）
var _frozen_head_tex: Texture2D
var _frozen_head_flip: bool
var _frozen_head_offset: Vector2
var _head_silhouette: Sprite2D


## 覆盖：除基类捕获的女人身体外，额外捕获骷髅头的当前帧
func _capture_freeze_frame(boss: Boss) -> void:
	super(boss)
	var head = boss.get_node_or_null("Visual/HeadAnimatedSprite2D") as AnimatedSprite2D
	if head and head.sprite_frames:
		_frozen_head_tex = head.sprite_frames.get_frame_texture(head.animation, head.frame)
		_frozen_head_flip = head.flip_h
		_frozen_head_offset = head.position


## 覆盖：除基类创建的女人身体剪影外，额外创建骷髅头黑色剪影
func _create_silhouettes() -> void:
	super()
	if _frozen_head_tex:
		_head_silhouette = Sprite2D.new()
		_head_silhouette.texture = _frozen_head_tex
		_head_silhouette.flip_h = _frozen_head_flip
		_head_silhouette.centered = true
		_head_silhouette.modulate = Color.BLACK
		_head_silhouette.position = _frozen_canvas_transform * (_frozen_boss_pos + _frozen_head_offset)
		add_child(_head_silhouette)


## 覆盖：同时销毁骷髅头剪影
func _remove_silhouettes() -> void:
	super()
	if _head_silhouette:
		_head_silhouette.queue_free()
		_head_silhouette = null


func _end_level() -> void:
	_is_playing = false
	is_death_playing = false

	if _boss:
		_boss.queue_free()
		_boss = null

	var player = get_tree().get_first_node_in_group("player")
	if player:
		PlayerStateManager.reset(player)
	LevelManager.spawn_point = "default"

	# 前往第五章过场动画
	Cutscene.target_chapter = 4
	get_tree().change_scene_to_file("res://scenes/ui/Cutscene.tscn")
