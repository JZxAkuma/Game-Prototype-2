extends Node3D

@onready var sun = $DirectionalLight3D
@onready var player_light = $"Player Boat/OmniLight3D"
var day_night_cycle: Node

@onready var camera = $Camera3D
@onready var ui = $ui

@export var sun_color_day: Color = Color(1.0, 0.95, 0.85)
@export var sun_color_sunset: Color = Color(1.0, 0.5, 0.3)
@export var sun_color_night: Color = Color(0.2, 0.25, 0.4)

@export var sun_energy_day: float = 1.2
@export var sun_energy_night: float = 0.0

var default_cam_pos
var default_cam_fov
var zoom_cam_fov = 25

var focusing = false
var focusing_on = null

@onready var dive_button = $"ui/Control/VBoxContainer/Dive Button"

# Keyframes: (hour, color). Must stay sorted by hour.
var color_keyframes = [
	[0.0, sun_color_night],
	[5.0, sun_color_night],
	[6.5, sun_color_sunset],
	[8.0, sun_color_day],
	[16.0, sun_color_day],
	[17.5, sun_color_sunset],
	[19.0, sun_color_night],
	[24.0, sun_color_night],
]


func _ready() -> void:
	ui.hide()
	default_cam_pos = camera.global_position
	default_cam_fov = camera.fov
	day_night_cycle = get_tree().get_first_node_in_group("day_night_cycle")
	if day_night_cycle:
		day_night_cycle.time_changed.connect(_on_time_changed)
	else:
		push_warning("Overworld: no node found in group 'day_night_cycle'")


func _on_time_changed(hour: float) -> void:
	_update_sun_rotation(hour)
	_update_sun_appearance(hour)
	_update_player_light(hour)


func _update_sun_rotation(hour: float) -> void:
	var angle_deg = (hour / 24.0) * 360.0 - 90.0
	sun.rotation_degrees.x = -angle_deg


func _get_day_amount(hour: float) -> float:
	if hour < 5.0 or hour >= 21.0:
		return 0.0
	elif hour < 7.0:
		return inverse_lerp(5.0, 7.0, hour)
	elif hour < 17.0:
		return 1.0
	elif hour < 19.0:
		return 1.0 - inverse_lerp(17.0, 19.0, hour)
	else:
		return 0.0


func _get_sun_color(hour: float) -> Color:
	for i in range(color_keyframes.size() - 1):
		var current = color_keyframes[i]
		var next = color_keyframes[i + 1]
		if hour >= current[0] and hour <= next[0]:
			var t = inverse_lerp(current[0], next[0], hour)
			return current[1].lerp(next[1], t)
	return sun_color_night 


func _update_sun_appearance(hour: float) -> void:
	var day_amount = _get_day_amount(hour)
	sun.light_energy = lerp(sun_energy_night, sun_energy_day, day_amount)
	sun.light_color = _get_sun_color(hour)


func _update_player_light(hour: float) -> void:
	var is_night = hour < 6.0 or hour >= 19.0
	player_light.visible = is_night

func _focus(target:Area3D,marker:Marker3D) -> void:
	if !target:
		return
	
	focusing = true
	focusing_on = target
	var target_pos = camera.global_position
	target_pos.x = marker.global_position.x
	target_pos.z = marker.global_position.z
	
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera,"global_position",target_pos,1)
	tween.tween_property(camera,"fov",zoom_cam_fov,2)
	_update_ui(target)

func _unfocus() -> void:
	focusing = false
	focusing_on = null
	var tween = create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera,"global_position",default_cam_pos,1)
	tween.tween_property(camera,"fov",default_cam_fov,2)
	_update_ui(null)

func _update_ui(target:Area3D) -> void:
	if focusing:
		ui.show()
	else:
		ui.hide()
	
	if target:
		if target.is_in_group("sector"):
			dive_button.show()
		else:
			dive_button.hide()

func _dive() -> void:
	if focusing_on:
		GameEvents.sector_selected.emit(focusing_on)
