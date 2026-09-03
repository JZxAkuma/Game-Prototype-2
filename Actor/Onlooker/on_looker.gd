extends CharacterBody3D
enum states{
	wandering,
	agitated,
	attack
}
var state = states.wandering
var wander_change_interval: float = 1.0
var wander_radius: float = 10.0
var home_position: Vector3
var avoid_ray_length: float = 3.0
var avoid_strength: float = 2.0
var target_direction: Vector3 = Vector3.FORWARD
var wander_timer: float = 5.0
var agitation_timer: float = 0.0
var swim_speed: float = 2.0
var attack_speed: float = 8.0
var turn_response: float = 2.0
var vertical_wander_bias: float = 0.15

@onready var ray_forward: RayCast3D = $"Nav Rays/Ray Front"
@onready var ray_left: RayCast3D = $"Nav Rays/Ray Left"
@onready var ray_right: RayCast3D = $"Nav Rays/Ray Right"
@onready var ray_up: RayCast3D = $"Nav Rays/Ray Up"
@onready var ray_down: RayCast3D = $"Nav Rays/Ray Down"


func _ready() -> void:
	home_position = global_position

func _setup_rays() -> void:
	for ray in [ray_forward,ray_left,ray_right,ray_up,ray_down]:
		ray.enabled = true
		ray.target_position = Vector3.ZERO

func _physics_process(delta: float) -> void:
	match state:
		states.wandering:
			_wandering(delta)

func _wandering(delta:float):
	wander_timer -= delta
	if wander_timer <= 0.0:
		_pick_new_wander_direction()

	var steer_dir = target_direction + _get_avoidance_vector() * avoid_strength
	steer_dir = steer_dir.normalized()

	_apply_steering(steer_dir,swim_speed,delta)
	move_and_slide()

func _apply_steering(desired_dir: Vector3, speed: float, delta: float) -> void:
	var t = 1.0 - exp(-turn_response * delta)
	var current_dir = -global_transform.basis.z
	var new_dir = current_dir.slerp(desired_dir, t).normalized()

	var right = new_dir.cross(Vector3.UP)
	if right.length() < 0.01:
		right = global_transform.basis.x
	right = right.normalized()
	var up = right.cross(new_dir).normalized()

	var target_basis = Basis(right, up, -new_dir)
	global_transform.basis = global_transform.basis.slerp(target_basis, t)

	velocity = -global_transform.basis.z * speed
	move_and_slide()

func _get_avoidance_vector() -> Vector3:
	var avoid = Vector3.ZERO
	var rays = [ray_forward,ray_left,ray_right,ray_up,ray_down]
	
	for ray in rays:
		if ray.is_colliding():
			var hit_point = ray.get_collision_point()
			var away = (global_position - hit_point).normalized()
			var closeness = 1.0 - (global_position.distance_to(hit_point)/avoid_ray_length)
			avoid += away * closeness

	return avoid

func _pick_new_wander_direction():
	wander_timer = wander_change_interval
	var random_offset := Vector3(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0) * vertical_wander_bias,
		randf_range(-1.0, 1.0)
	).normalized() * randf_range(0.0, wander_radius)

	var target_point: Vector3 = home_position + random_offset
	target_direction = (target_point - global_position).normalized()
	
	
