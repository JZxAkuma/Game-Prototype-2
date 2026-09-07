extends Node3D
@onready var world_container = $"World Container"

func _ready():
	WorldChanger.register_container(world_container)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
