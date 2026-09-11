extends Node3D

@export var sector_name: String = ""
var spawn_y_level: float = 80

func _ready() -> void:
	var resolved_sector = sector_name
	if resolved_sector == "":
		resolved_sector = get_parent().name

	var active_missions = QuestManager._get_missions_for_sector(resolved_sector)

	for mission in active_missions:
		
		if mission.type == Mission.Type.CREATURE and mission.objective_scene:
			var obj = mission.objective_scene.instantiate()
			obj.position.y = spawn_y_level
			add_child(obj)
			
