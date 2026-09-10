extends Node3D

@export var objective_id: String = ""

func _ready() -> void:
	if _is_objective_active():
		add_to_group("quest_objective")
	else:
		visible = false
		set_process(false)
		set_physics_process(false)


func _is_objective_active() -> bool:
	for mission in QuestManager.missions:
		if mission.objective_id == objective_id and mission.state == Mission.State.ACCEPTED:
			return true
	return false
