extends CharacterBody2D

var animations: Node2D
var current_sprite: AnimatedSprite2D = null
var facing_right: bool = true

@export var walk_speed: int = 150
@export var gravity: int = 980
@export var jump_speed: int = -400

func _ready():
	animations = find_child("Animations", true, false)
	if animations == null:
		print("错误：未找到 Animations 节点")
		return
	for child in animations.get_children():
		child.visible = false

func play_animation(anim_name: String):
	if animations == null:
		return
	var sprite_node_name = _get_sprite_node_name(anim_name)
	var sprite = animations.get_node(sprite_node_name) as AnimatedSprite2D
	if sprite == null:
		print("找不到动画节点: ", sprite_node_name)
		return
	for child in animations.get_children():
		child.visible = false
	sprite.visible = true
	sprite.play(anim_name)
	current_sprite = sprite
	# 所有动画都根据朝向翻转，不只是idle
	set_flip(not facing_right)

func _get_sprite_node_name(anim_name: String) -> String:
	match anim_name:
		"idle": return "IdleSprite"
		"run": return "RunSprite"
		"jump": return "JumpSprite"
		"fall": return "FallSprite"
		_: return "IdleSprite"

func set_flip(flip: bool):
	if current_sprite:
		current_sprite.flip_h = flip
	facing_right = not flip

func _physics_process(delta):
	if not is_on_floor():
		velocity.y += gravity * delta
	move_and_slide()
