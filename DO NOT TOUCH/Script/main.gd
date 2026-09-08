extends Node3D
@onready var world_container = $"World Container"

func _ready():
	WorldChanger.register_container(world_container)
	get_viewport().physics_object_picking = true
	GameEvents.sector_selected.connect(_on_sector_selected)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _on_sector_selected(sector: Node) -> void:
	print("Selected: ", sector.name)
	var scene = sector._get_underwater_scene()
	if scene:
		pass
