extends Node3D
@onready var world_container = $"World Container"
@export var overworld : PackedScene
@export var worldtscn : PackedScene
@export var mainmenu : PackedScene
@export var tutorial : PackedScene
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
	WorldChanger.register_container(world_container)
	get_viewport().physics_object_picking = true
	GameEvents.sector_selected.connect(_on_sector_selected)
	GameEvents.surface.connect(_on_surface)

#func _physics_process(delta: float) -> void:
	#if Input.is_action_just_pressed("ui_cancel"):
		#if state != states.diving:
			#WorldChanger.goto_scene(mainmenu)
		#elif state == states.overworld:
			#WorldChanger.goto_scene(mainmenu)
#
		#else:
			#GameEvents.surface.emit()
		
	if Input.is_action_just_pressed("change scene test"):
		_surface()

func _on_sector_selected(sector: Node) -> void:
	_dive(sector)

func _on_surface() -> void:
	_surface()

func _surface()->void:
	WorldChanger.goto_scene(overworld)
	state = states.overworld
		
func _dive(sector:Node)->void:
	var scene = sector._get_underwater_scene()
	if scene:
		WorldChanger.goto_scene(scene)
		state = states.diving

func _to_overworld() -> void:
	WorldChanger.goto_scene(overworld)
	state = states.overworld
	MusicPlayer.pause()

func _to_wrld_scn() -> void:
	WorldChanger.goto_scene(worldtscn)

func _to_tutorial() -> void:
	WorldChanger.goto_scene(tutorial)
	
