extends CharacterBody3D

enum states{
	driving
}

var state = states.driving

@export var mouse_sensitivity: float = 0.15
@export var acceleration: float = 0.02
@export var deceleration: float = 0.02

@export var look_smoothness: float = 1.0

@export var deadzone: float = 0.1          
@export var stick_range: float = 0.6       
@export var max_turn_rate_deg: float = 60.0
@export var turn_response: float = 4.0
@export var pitch_limit_deg: float = 80.0
@export var handling: float = 0.8

@onready var main_camera = $Camera3D
@onready var viewfinder_viewport = $PhotoUI/SubViewportContainer/SubViewport
@onready var viewfinder_camera = $PhotoUI/SubViewportContainer/SubViewport/ViewFinderCamera
@onready var photo_ui = $PhotoUI
@onready var gallery_ui = $GalleryUI
@onready var gallery_grid = $GalleryUI/PhotoGrid

@onready var sub_mesh = $Sub_mesh

var freelook_sens = 0.005

var freelook_active = false
var freelook_yaw = 0.0
var freelook_pitch = 0.0

var shake_threshold: float = 0.5
var max_shake_strength: float = 0.01

var sub_mesh_base_pos: Vector3
var camera_equipped = false
var photos:Array[ImageTexture] = []

var stick_input: Vector2 = Vector2.ZERO

var current_yaw_rate: float = 0.0
var current_pitch_rate: float = 0.0


var max_speed = 5

var throttle_power = 0
var mnk_max_throttle_step = 3.0
var mnk_throttle_step = 0.0

var water_drag = 2

var target_yaw: float = 0.0
var target_pitch: float = 0.0
var current_yaw: float = 0.0
var current_pitch: float = 0.0

func _debug_display():
	$"Debug/Debug Display/VBoxContainer/Speed".text = "Velocity: " + str(velocity) + " target: "
	$"Debug/Debug Display/VBoxContainer/Throttle".text = "Throttle Power: " + str(throttle_power) + "\n" + "fps: " + str(Engine.get_frames_per_second()) + "\n" + "Global Pos: " + str(global_position) 


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED  
	current_yaw = rotation.y
	current_pitch = rotation.x
	
	viewfinder_viewport.world_3d = get_viewport().world_3d
	photo_ui.visible = false
	gallery_ui.visible = false
	
	sub_mesh_base_pos = sub_mesh.position

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle freelook"):
		_toggle_freelook()

	if freelook_active and event is InputEventMouseMotion:
		freelook_yaw -= event.relative.x * freelook_sens
		freelook_pitch -= event.relative.y * freelook_sens
		freelook_pitch = clamp(freelook_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		get_tree().quit()
	


func _physics_process(delta: float) -> void:
	_debug_display()
	match state:
		states.driving:
			_handle_shake()
			_camera_control()
			if not freelook_active:
				_update_stick()
			_sub_pitch_yaw(delta)
			_throttle_input_handler()
			_propeller(delta)

func _camera_control():
	if freelook_active:
		main_camera.rotation.y = freelook_yaw
		main_camera.rotation.x = freelook_pitch
		
	if camera_equipped:
		viewfinder_camera.global_transform = main_camera.global_transform
	if Input.is_action_just_pressed("camera equip"):
		_toggle_camera()
	if Input.is_action_just_pressed("take picture") and camera_equipped:
		_take_picture()
	if Input.is_action_just_pressed("gallery"):
		_toggle_gallery()

func _toggle_camera() -> void:
	camera_equipped = !camera_equipped
	photo_ui.visible = camera_equipped

func _take_picture() -> void:
	var img : Image = viewfinder_viewport.get_texture().get_image()
	var photo_tex : ImageTexture = ImageTexture.create_from_image(img)
	photos.append(photo_tex)

func _toggle_gallery() -> void:
	gallery_ui.visible = !gallery_ui.visible
	if gallery_ui.visible:
		_refresh_gallery()

func _refresh_gallery() -> void:
	for child in gallery_grid.get_children():
		child.queue_free()
		
	for photo in photos:
		var rect = TextureRect.new()
		rect.texture = photo
		rect.custom_minimum_size = Vector2(160,120)
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		gallery_grid.add_child(rect)

func _update_stick() -> void:
	var viewport_size = get_viewport().get_visible_rect().size
	var center = viewport_size / 2.0
	var mouse_pos = get_viewport().get_mouse_position()
	var half_size = center * stick_range
	var raw = Vector2(
		(mouse_pos.x - center.x) / half_size.x,
		-(mouse_pos.y - center.y) / half_size.y 
	)
	var mag = raw.length()
	if mag < deadzone:
		stick_input = Vector2.ZERO
	else:
		var rescaled_mag = (mag - deadzone) / (1.0 - deadzone)
		rescaled_mag = clamp(rescaled_mag, 0.0, 1.0)
		stick_input = raw.normalized() * rescaled_mag

func _sub_pitch_yaw(delta: float) -> void:
	var speed_fraction = clamp(velocity.length() / max_speed, 0.0, 1.0)
	var turn_penalty = clamp(speed_fraction * handling, 0.0, 1.0)
	var current_max_turn_rate = deg_to_rad(max_turn_rate_deg) * (1.0 - turn_penalty)

	var target_yaw_rate = -stick_input.x * current_max_turn_rate
	var target_pitch_rate = stick_input.y * current_max_turn_rate 

	var t: float = 1.0 - exp(-turn_response * delta)
	current_yaw_rate = lerp(current_yaw_rate, target_yaw_rate, t)
	current_pitch_rate = lerp(current_pitch_rate, target_pitch_rate, t)

	rotation.y += current_yaw_rate * delta
	rotation.x += current_pitch_rate * delta
	rotation.x = clamp(rotation.x, deg_to_rad(-pitch_limit_deg), deg_to_rad(pitch_limit_deg))

	move_and_slide()

func _throttle_input_handler() -> void:
	if Input.is_action_just_pressed("Throttle up"):
		mnk_throttle_step += 1
	elif Input.is_action_just_pressed("Throttle down"):
		mnk_throttle_step -= 1
	elif Input.is_action_just_pressed("reverse"):
		mnk_throttle_step = -1
			
	mnk_throttle_step = clamp(mnk_throttle_step,-1,mnk_max_throttle_step)
	throttle_power = 100 * (mnk_throttle_step/mnk_max_throttle_step)
	throttle_power = clamp(throttle_power, -100, 100)

func _propeller(delta: float) -> void:
	var forward = -global_transform.basis.z
	
	if throttle_power > 0:
		velocity += forward * throttle_power * acceleration * delta
	elif throttle_power < 0:
		velocity += forward * throttle_power * acceleration * delta
	
	if throttle_power != 0:
		var current_max_speed = (abs(throttle_power) / 100.0) * max_speed
		if velocity.length() > current_max_speed:
			velocity = velocity.normalized() * current_max_speed
	
	move_and_slide()

func _handle_shake() -> void:
	var speed_fraction = clamp(velocity.length() / max_speed, 0.0, 1.0)

	if speed_fraction < shake_threshold:
		sub_mesh.position = sub_mesh_base_pos
		return


	var shake_t = (speed_fraction - shake_threshold) / (1.0 - shake_threshold)
	var strength = shake_t * max_shake_strength

	var offset = Vector3(
		randf_range(-strength, strength),
		randf_range(-strength, strength),
		randf_range(-strength, strength)
	)

	sub_mesh.position = sub_mesh_base_pos + offset

func _pass_camera():
	return $PhotoUI/SubViewportContainer/SubViewport/ViewFinderCamera
	
func _toggle_freelook():
	freelook_active = !freelook_active
	
	if freelook_active:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		var center = get_viewport().get_visible_rect().size / 2.0
		Input.warp_mouse(center)
		freelook_yaw = 0.0
		freelook_pitch = 0.0
		main_camera.rotation = Vector3.ZERO
	
	
	
	
