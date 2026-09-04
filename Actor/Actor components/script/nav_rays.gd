extends Node3D

@export var ray_cast_lenght:float = 5

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for i in get_children():
		i.add_exception(self.get_parent())
	
	$"Ray Front".target_position = Vector3(0,0,-ray_cast_lenght)
	$"Ray Left".target_position = Vector3(-ray_cast_lenght,0,0)
	$"Ray Right".target_position = Vector3(ray_cast_lenght,0,0)
	$"Ray Down".target_position = Vector3(0,-ray_cast_lenght,0)
	$"Ray Up".target_position = Vector3(0,-ray_cast_lenght,0)

# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass
