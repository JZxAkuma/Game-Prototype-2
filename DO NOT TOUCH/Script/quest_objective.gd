extends Node3D

@export var creature_id: String = ""  


func _ready() -> void:
	if creature_id == "":
		push_warning("QuestObjective on '%s' has no creature_id set" % get_parent().name)
		return

	add_to_group("photographable")  
