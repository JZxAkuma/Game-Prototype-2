extends Node3D

@export var sector_name:String

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var active_missions = QuestManager._get_missions_for_sector(sector_name)
	for mission in active_missions:
		
		if mission.objective_scene:
			var obj = mission.objective_scene.instantiate()
			add_child(obj)
