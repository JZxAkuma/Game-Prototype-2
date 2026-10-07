extends Node3D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_start_button_pressed() -> void:
	$"../.."._to_overworld()


func _on_world_scene_button_pressed() -> void:
	$"../.."._to_wrld_scn()

func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _on_quit_button_2_pressed() -> void:
	_open_photos_folder()

func _open_photos_folder() -> void:
	var real_path = ProjectSettings.globalize_path(PhotoManager.PHOTOS_DIR)
	OS.shell_open(real_path)
