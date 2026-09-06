extends Node3D
@onready var world_container = $"World Container"

func _ready():
	WorldChanger.register_container(world_container)
