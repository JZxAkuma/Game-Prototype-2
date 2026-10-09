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
@export var overworld: PackedScene

@onready var main_camera = $Camera3D
@onready var viewfinder_viewport = $SubViewport
@onready var viewfinder_camera = $SubViewport/ViewFinderCamera
@onready var photo_ui = $PhotoUI
@onready var gallery_ui = $GalleryUI
@onready var gallery_grid = $GalleryUI/PhotoGrid

@onready var sub_mesh = $Sub_mesh
@onready var photo_review_ui = $PhotoReviewUI/Control
@onready var latest_photo_screen = $"Latest photo"

@onready var steering_wheel: Node3D = $"Sub_mesh/Node3D/steering wheel/SteeringWheelTop"
@onready var camera_mount: Marker3D = $"Sub_mesh/Camera mount"

@onready var throttle_lever = $"Sub_mesh/throttle input/lever"

@onready var tablet: Node3D = $Sub_mesh/tablet
@onready var tablet_screen = $Sub_mesh/tablet/MeshInstance3D

@onready var crosshair: CanvasLayer = $crosshair


var freelook_sens = 0.005

var freelook_active = false
var freelook_yaw = 0.0
var freelook_pitch = 0.0

var shake_threshold: float = 0.5
var max_shake_strength: float = 0.001

var sub_mesh_base_pos: Vector3
var camera_equipped = false
var photos: Array = []

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

var pending_photo: Image = null
var pending_mission: Mission = null

var ui_locked: bool = false

@export var engine_response: float = 1.5
@export var engine_pitch_min: float = 0.9
@export var engine_pitch_max: float = 1.3

@onready var idle_player = $Audio/Idle
@onready var mid_player = $Audio/Mid
@onready var high_player = $Audio/High

@export var tablet_hidden_offset: Vector3 = Vector3(0, -0.3, 0) 
@export var tablet_tween_time: float = 0.35

var tablet_shown_pos: Vector3
var tablet_tween: Tween

var engine_rpm: float = 0.0

func _debug_display():
	$"Debug/Debug Display/VBoxContainer/Speed".text = "Velocity: " + str(velocity) + " target: "
	$"Debug/Debug Display/VBoxContainer/Throttle".text = "Throttle Power: " + str(throttle_power) + "\n" + "fps: " + str(Engine.get_frames_per_second()) + "\n" + "Global Pos: " + str(global_position) 

@export var screen_uv_scale: Vector3 = Vector3(1, 1, 1)
@export var screen_uv_offset: Vector3 = Vector3(0, 0, 0)

@onready var click_sound = $Audio/Click
@onready var interact_ray: RayCast3D = $Camera3D/RayCast3D
var hovered: Node = null
func _ready() -> void:
	MusicPlayer.start()
	crosshair.hide()
	_setup_screen_material()
	tablet_shown_pos = tablet.position 
	tablet.position = tablet_shown_pos + tablet_hidden_offset
	tablet.hide()
	for p in [idle_player, mid_player, high_player]:
		if not p.playing:
			p.play()
	Input.mouse_mode = Input.MOUSE_MODE_CONFINED  
	current_yaw = rotation.y
	current_pitch = rotation.x
	
	viewfinder_viewport.world_3d = get_viewport().world_3d
	photo_ui.visible = false
	gallery_ui.visible = false
	photo_review_ui.retry_pressed.connect(_on_retry_pressed)
	photo_review_ui.submit_pressed.connect(_on_submit_pressed)
	sub_mesh_base_pos = sub_mesh.position

func _unhandled_input(event: InputEvent) -> void:
	if ui_locked:
		return
	if event.is_action_pressed("toggle freelook"):
		_toggle_freelook()

	if freelook_active and event is InputEventMouseMotion:
		freelook_yaw -= event.relative.x * freelook_sens
		freelook_pitch -= event.relative.y * freelook_sens
		freelook_pitch = clamp(freelook_pitch, deg_to_rad(-80.0), deg_to_rad(80.0))

	#if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		#get_tree().quit()
	


func _physics_process(delta: float) -> void:
	
	#if Input.is_action_just_pressed("change scene test"):
		#WorldChanger.goto_scene("res://Underwater Template/tier_3.tscn")
	if Input.is_action_just_pressed("ui_cancel"):
		GameEvents.emit_signal("surface")
	_debug_display()
	match state:
		states.driving:
			_update_engine_sound(delta)
			_handle_shake()
			_camera_control()
			_update_interact()
			if not freelook_active:
				_update_stick()
			_sub_pitch_yaw(delta)
			_throttle_input_handler()
			_propeller(delta)

func _update_interact() -> void:
	if ui_locked:
		return
	var target: Node = null

	if freelook_active and interact_ray.is_colliding():
		var c = interact_ray.get_collider()
		if c and c.has_method("interact"):
			target = c

	if target != hovered:
		if is_instance_valid(hovered) and hovered.has_method("hover_exit"):
			hovered.hover_exit()
		hovered = target
		if hovered and hovered.has_method("hover_enter"):
			hovered.hover_enter()

	if hovered and Input.is_action_just_pressed("interact"):
		hovered.interact()

func _setup_screen_material() -> void:
	var mat = StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = viewfinder_viewport.get_texture()
	tablet_screen.material_override = mat

func _fit_viewport_to_screen() -> void:
	var s = tablet_screen.mesh.get_aabb().size
	var dims = [s.x, s.y, s.z]
	dims.sort()                   
	var ratio = dims[2] / dims[1]    
	var height = 480
	viewfinder_viewport.size = Vector2i(int(height * ratio), height)



func _update_engine_sound(delta: float) -> void:
	var target = abs(throttle_power) / 100.0
	engine_rpm = lerp(engine_rpm, target, 1.0 - exp(-engine_response * delta))

	var idle_w = clamp(1.0 - engine_rpm * 2.0, 0.0, 1.0)
	var mid_w = 1.0 - abs(engine_rpm * 2.0 - 1.0)
	var high_w = clamp(engine_rpm * 2.0 - 1.0, 0.0, 1.0)

	idle_player.volume_db = linear_to_db(max(idle_w, 0.0001))
	mid_player.volume_db = linear_to_db(max(mid_w, 0.0001))
	high_player.volume_db = linear_to_db(max(high_w, 0.0001))

	var pitch = lerp(engine_pitch_min, engine_pitch_max, engine_rpm)
	idle_player.pitch_scale = pitch
	mid_player.pitch_scale = pitch
	high_player.pitch_scale = pitch

func _camera_control():
	if freelook_active:
		main_camera.rotation.y = freelook_yaw
		main_camera.rotation.x = freelook_pitch
		
	if camera_equipped:
		viewfinder_camera.global_transform = camera_mount.global_transform
	if Input.is_action_just_pressed("camera equip"):
		_toggle_camera()
	if Input.is_action_just_pressed("take picture") and camera_equipped:
		_take_picture()
	if Input.is_action_just_pressed("gallery"):
		_toggle_gallery()

func _toggle_camera() -> void:
	camera_equipped = !camera_equipped

	if tablet_tween:
		tablet_tween.kill() 
	tablet_tween = create_tween()
	tablet_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	if camera_equipped:
		tablet.show()
		tablet_tween.tween_property(tablet, "position", tablet_shown_pos, tablet_tween_time)
	else:
		tablet_tween.tween_property(tablet, "position", tablet_shown_pos + tablet_hidden_offset, tablet_tween_time)
		tablet_tween.tween_callback(tablet.hide)   
	viewfinder_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if camera_equipped else SubViewport.UPDATE_DISABLED
	
func _take_picture() -> void:
	if pending_photo != null:
		return 

	click_sound.play()   

	var img: Image = viewfinder_viewport.get_texture().get_image()
	var captured_id = _check_creatures_in_frame()

	var matching_mission = _find_matching_accepted_mission(captured_id)

	if matching_mission:
		pending_photo = img
		pending_mission = matching_mission
		photo_review_ui.show_review(img)
	else:
		_finalize_photo(img, captured_id)

func _find_matching_accepted_mission(objective_id: String) -> Mission:
	if objective_id == "":
		return null
	for mission in QuestManager.missions:
		if mission.objective_id == objective_id and mission.state == Mission.State.ACCEPTED:
			return mission
	return null

func _finalize_photo(img: Image, objective_id: String) -> void:
	var entry = PhotoManager.save_photo(img, objective_id)
	var photo_tex = ImageTexture.create_from_image(img)
	photos.append({"texture": photo_tex, "objective_id": objective_id, "filename": entry["filename"]})
	latest_photo_screen._load_latest_photo()


func _on_retry_pressed() -> void:
	print("retry pressed")
	pending_photo = null
	pending_mission = null
	photo_review_ui.hide_review()


func _on_submit_pressed() -> void:
	if pending_mission and pending_photo:
		_finalize_photo(pending_photo, pending_mission.objective_id)
		QuestManager._complete_mission(pending_mission)

	pending_photo = null
	pending_mission = null
	photo_review_ui.hide_review()

	GameEvents.emit_signal("surface")

func _check_creatures_in_frame() -> String:
	var creatures = get_tree().get_nodes_in_group("photographable")
	var space_state = get_world_3d().direct_space_state

	for creature in creatures:
		var pos = creature.global_position

		if not viewfinder_camera.is_position_in_frustum(pos):
			continue

		var distance = viewfinder_camera.global_position.distance_to(pos)
		if distance > 30.0:
			continue

		var query = PhysicsRayQueryParameters3D.create(viewfinder_camera.global_position, pos)
		var result = space_state.intersect_ray(query)
		if result and result.collider != creature and not result.collider.is_ancestor_of(creature) and not creature.is_ancestor_of(result.collider):
			continue

		return creature.creature_id

	return ""

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
	
	steering_wheel.rotation.y = -(stick_input.x * 1.5)
	steering_wheel.position.y = stick_input.y * 0.1
	
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

	throttle_lever.position.z = remap(mnk_throttle_step, -1, mnk_max_throttle_step, 0.009, -0.02)
	
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
		crosshair.show()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	else:
		crosshair.hide()
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		var center = get_viewport().get_visible_rect().size / 2.0
		Input.warp_mouse(center)
		freelook_yaw = 0.0
		freelook_pitch = 0.0
		main_camera.rotation = Vector3.ZERO
	
	
	
	
