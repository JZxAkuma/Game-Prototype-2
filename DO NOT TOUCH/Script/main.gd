extends Node3D
@onready var world_container = $"World Container"
@export var overworld : PackedScene

@export var missions:Array[Mission]

enum states{
	diving,
	overworld
}
var state = states.overworld
var selected_sector

func _ready():
	for i in missions:
		QuestManager._register_mission(i)
	for m in QuestManager.missions:
		QuestManager._accept_mission(m)
	WorldChanger.register_container(world_container)
	get_viewport().physics_object_picking = true
	GameEvents.sector_selected.connect(_on_sector_selected)
	GameEvents.surface.connect(_on_surface)

func _physics_process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		if state != states.diving:
			get_tree().quit()
		else:
			GameEvents.surface.emit()
		
	if Input.is_action_just_pressed("change scene test"):
		_surface()

func _on_sector_selected(sector: Node) -> void:
	_dive(sector)

func _on_surface() -> void:
	_surface()

func _surface()->void:
	if state == states.diving:
		WorldChanger.goto_scene(overworld)
		state = states.overworld
		
func _dive(sector:Node)->void:
	var scene = sector._get_underwater_scene()
	if scene:
		WorldChanger.goto_scene(scene)
		state = states.diving
