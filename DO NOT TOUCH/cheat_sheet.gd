extends Area3D

@onready var tutorial: CanvasLayer = $"../../Tutorial"
@onready var mesh: MeshInstance3D = $cheatsheet2
@onready var player = $"../.." 


func _ready() -> void:
	mesh.hide()
	tutorial.hide()


func hover_enter() -> void:
	mesh.show()


func hover_exit() -> void:
	mesh.hide()


func interact() -> void:
	if tutorial.visible:
		return
	tutorial.show()
	player.ui_locked = true
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED
	Input.warp_mouse(get_viewport().get_visible_rect().size / 2.0)


func _on_tutorial_pressed() -> void:
	tutorial.hide()
	player.ui_locked = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED 
