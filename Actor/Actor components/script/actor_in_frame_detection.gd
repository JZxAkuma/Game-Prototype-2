extends Node3D

signal watch_started
signal watch_stopped
signal provoked
# Called when the node enters the scene tree for the first time.
@export var detection_range: float = 12.0
@export var detection_fov_deg: float = 30.0
@export var agitation_time: float = 1.0

var is_being_watched: bool = false
var agitation_timer: float = 0.0
var has_provoked: bool = false

var player_camera: Camera3D


func _ready() -> void:
	player_camera = get_viewport().get_camera_3d()


func _physics_process(delta: float) -> void:
	if not player_camera:
		player_camera = get_viewport().get_camera_3d()
		return

	var watched_now = _check_watched()

	if watched_now and not is_being_watched:
		is_being_watched = true
		watch_started.emit()
	elif not watched_now and is_being_watched:
		is_being_watched = false
		agitation_timer = 0.0
		has_provoked = false
		watch_stopped.emit()

	if watched_now:
		agitation_timer += delta
		if agitation_timer >= agitation_time and not has_provoked:
			has_provoked = true
			provoked.emit()


func _check_watched() -> bool:
	var to_self = global_position - player_camera.global_position
	var distance = to_self.length()

	if distance > detection_range:
		return false

	var cam_forward = -player_camera.global_transform.basis.z
	var angle = rad_to_deg(cam_forward.angle_to(to_self.normalized()))

	return angle < detection_fov_deg
