extends CanvasLayer

@onready var hp_fill = $HUD/HPBarFill
@onready var mp_fill = $HUD/MPBarFill
@onready var tp_fill = $HUD/TPBarFill
@onready var ninjutsu_icon = $HUD/NinjutsuIcon

var _ninjutsu_connected: bool = false

var ninjutsu_textures: Array[Texture2D] = [
	preload("res://assets/sprites/ui/fire_ninjutsu.png"),
	preload("res://assets/sprites/ui/fireball_ninjutsu.png"),
	preload("res://assets/sprites/ui/edge_blade_ninjutsu.png"),
	preload("res://assets/sprites/ui/boomerang_ninjutsu.png"),
]

var cd_masks: Dictionary = {}
var cd_full_height: float = 16.0

func _ready() -> void:
	cd_masks = {
		"dash": $HUD/CD_Dash/CDMask,
		"uppercut": $HUD/CD_Uppercut/CDMask,
		"downslash": $HUD/CD_Downslash/CDMask,
		"spin": $HUD/CD_Spin/CDMask,
		"finish": $HUD/CD_Finish/CDMask,
	}
	cd_full_height = cd_masks["dash"].size.y

func _process(_delta: float) -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		return
	
	_update_bar(hp_fill, player.current_hp, player.data.max_hp)
	_update_bar(mp_fill, player.ninjutsu.current_mp, player.data.max_mp)
	_update_bar(tp_fill, player.sword.current_tp, player.sword.MAX_TP)
	
	_update_cd_masks(player)
	
	if not _ninjutsu_connected:
		player.ninjutsu.ninjutsu_switched.connect(_update_ninjutsu_icon)
		_ninjutsu_connected = true

func _update_bar(bar: Sprite2D, current_value: float, max_value: float) -> void:
	if current_value <= 0:
		bar.hide()
		bar.scale.x = 0
	else:
		bar.show()
		bar.scale.x = float(current_value) / float(max_value)

func _update_cd_masks(player: Player) -> void:
	for skill_name in cd_masks.keys():
		var mask = cd_masks[skill_name]
		var remaining = player.sword.get_cooldown_remaining(skill_name)
		
		if remaining <= 0:
			mask.size.y = 0
			mask.hide()
		else:
			mask.show()
			var max_cd = player.sword.FINISH_COOLDOWN_TIME if skill_name == "finish" else player.sword.COOLDOWN_TIME
			var ratio = remaining / float(max_cd)
			mask.size.y = cd_full_height * ratio

func _update_ninjutsu_icon(index: int, _name: String) -> void:
	if index >= 0 and index < ninjutsu_textures.size():
		ninjutsu_icon.texture = ninjutsu_textures[index]
