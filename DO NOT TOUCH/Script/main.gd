extends Node3D
@onready var world_container = $"World Container"

@export var overworld : PackedScene

enum states{
	diving,
	overworld
}

var state = states.diving

var selected_sector

func _ready():
	WorldChanger.register_container(world_container)
	get_viewport().physics_object_picking = true
	GameEvents.sector_selected.connect(_on_sector_selected)
	

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("change scene test"):
		_surface()

func _on_sector_selected(sector: Node) -> void:
	_dive(sector)

func _surface()->void:
	if state == states.diving:
		WorldChanger.goto_scene(overworld)

func _dive(sector:Node)->void:
	var scene = sector._get_underwater_scene()
	if scene:
		WorldChanger.goto_scene(scene)
