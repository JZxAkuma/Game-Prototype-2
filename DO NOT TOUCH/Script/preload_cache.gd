extends Node3D

@export var scenes_to_preload: Array[PackedScene] = []
@onready var progress_label = $CanvasLayer/Control/Label  

var loaded_count := 0

func _ready() -> void:
	await get_tree().process_frame 
	_warm_up_shaders()


func _warm_up_shaders() -> void:
	for scene in scenes_to_preload:
		var instance = scene.instantiate()
		add_child(instance)

		if instance is Node3D:
			instance.position = Vector3(0, -9999, 0)

		await get_tree().process_frame
		await get_tree().process_frame

		loaded_count += 1
		if progress_label:
			progress_label.text = "Pre cashing\n %d / %d" % [loaded_count, scenes_to_preload.size()] + " item(S)"

		instance.queue_free()
		await get_tree().process_frame

	get_tree().change_scene_to_file("res://DO NOT TOUCH/main.tscn")
