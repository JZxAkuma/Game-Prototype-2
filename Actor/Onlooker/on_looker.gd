extends CharacterBody3D

enum states{
	wandering,
	agitated,
	attack
}

var state = states.wandering

func _physics_process(delta: float) -> void:
	match state:
		states.wandering:
			pass

func _wandering():
	pass
