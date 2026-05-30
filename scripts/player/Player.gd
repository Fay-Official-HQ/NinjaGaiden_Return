extends CharacterBody2D

class_name Player

@export var data: PlayerData

@onready var input: InputComponent = $Components/InputComponent
@onready var movement: MovementComponent = $Components/MovementComponent


func _ready():

	movement.initialize(self)


func _process(_delta):

	input.update_input()


func _physics_process(delta):

	movement.apply_gravity(delta)

	move_and_slide()
