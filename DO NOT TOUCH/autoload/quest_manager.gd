extends Node

signal mission_completed(mission: Mission)

var missions : Array[Mission] = []

func _register_mission(mission: Mission) -> void:
	missions.append(mission)
	
func _get_available_mission_for_island(island_name:String) -> Array[Mission]:
	var result: Array[Mission] = []
	for m in missions:
		if m.giver_island == island_name and m.state == Mission.State.AVAILABLE:
			result.append(m)
	
	return result

func _get_all_missions_for_island(island_name: String) -> Array[Mission]:
	var result: Array[Mission] = []
	for m in missions:
		if m.giver_island == island_name:
			result.append(m)
	return result

func _get_missions_for_sector(sector_name: String) -> Array[Mission]:
	var result: Array[Mission] = []
	for m in missions:
		if m.sector_name == sector_name and m.state == Mission.State.ACCEPTED:
			result.append(m)
	return result

func _accept_mission(mission: Mission) -> void:
	if mission.state == Mission.State.AVAILABLE:
		mission.state = Mission.State.ACCEPTED

func _submit_mission(mission: Mission) -> bool:
	if mission.state != Mission.State.COMPLETED:
		return false

	if PhotoManager.has_photo_for_objective(mission.objective_id):
		mission.state = Mission.State.SUBMITTED
		return true
	return false

func _complete_mission(mission: Mission) -> void:
	if mission.state == Mission.State.ACCEPTED:
		mission.state = Mission.State.COMPLETED
