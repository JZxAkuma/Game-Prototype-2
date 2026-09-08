extends Node

@export var transition_time: float = 1.0

var focus_camera: Camera3D = null

var is_focused: bool = false
var return_transform: Transform3D

func _ready() -> void:
	GameEvents.object_focused.connect(_on_object_focused)
	GameEvents.focus_exited.connect(_on_focus_exited)

func register_focus_camera(camera: Camera3D) -> void:
	focus_camera = camera

func _on_object_focused(marker: Marker3D) -> void:
	if is_focused or not focus_camera:
		return
	is_focused = true

	return_transform = focus_camera.global_transform
	focus_camera.current = true

	var target_position = focus_camera.global_position
	target_position.x = marker.global_position.x
	target_position.z = marker.global_position.z + 10

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(focus_camera, "global_position", target_position, transition_time)

func _on_focus_exited() -> void:
	if not is_focused:
		return

	var tween = create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(focus_camera, "global_transform", return_transform, transition_time)
	await tween.finished

	is_focused = false
