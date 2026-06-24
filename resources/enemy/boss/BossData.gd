extends Resource
class_name BossData

@export var boss_name: String = "影之守护者"
@export var max_hp: int = 32
@export var move_speed: float = 80.0
@export var rush_speed: float = 400.0
@export var rush_damage: int = 2
@export var slash_damage: int = 2
@export var attack_cooldown: float = 1.5
@export var hurt_invincible_time: float = 0.5
@export var death_anim_duration: float = 3.0
@export var defeat_next_scene: String = ""
@export var defeat_spawn_point: String = "default"
