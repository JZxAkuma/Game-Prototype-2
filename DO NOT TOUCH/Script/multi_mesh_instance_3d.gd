extends MultiMeshInstance3D

@export var fish_count: int = 30
@export var swim_speed: float = 4.0
@export var turn_response: float = 2.0
@export var school_radius: float = 20.0
@export var separation_distance: float = 2
@export var wander_change_interval: float = 4.0
@export var wander_strength: float = 0.6

var home_position: Vector3 = Vector3.ZERO

var positions: Array[Vector3] = []
var directions: Array[Vector3] = []
var wander_targets: Array[Vector3] = []
var wander_timers: Array[float] = []


func _ready() -> void:
	home_position = Vector3.ZERO
	multimesh.use_custom_data = true
	multimesh.instance_count = fish_count

	for i in range(fish_count):
		var pos = home_position + Vector3(
			randf_range(-school_radius, school_radius),
			randf_range(-school_radius * 0.3, school_radius * 0.3),
			randf_range(-school_radius, school_radius)
		)
		positions.append(pos)
		directions.append(Vector3.FORWARD)
		wander_targets.append(Vector3.FORWARD)
		wander_timers.append(randf_range(0.0, wander_change_interval))   # stagger initial timers

		multimesh.set_instance_custom_data(i, Color(randf_range(0.0, 10.0), 0, 0, 0))


func _physics_process(delta: float) -> void:
	for i in range(fish_count):
		wander_timers[i] -= delta
		if wander_timers[i] <= 0.0:
			wander_timers[i] = wander_change_interval
			wander_targets[i] = Vector3(
				randf_range(-1.0, 1.0),
				randf_range(-0.3, 0.3),
				randf_range(-1.0, 1.0)
			).normalized()

		var boid_steer = _get_boid_steering(i)
		var combined = boid_steer + wander_targets[i] * wander_strength
		var desired_dir = (directions[i] + combined).normalized()

		var t = 1.0 - exp(-turn_response * delta)
		directions[i] = directions[i].slerp(desired_dir, t)

		positions[i] += directions[i] * swim_speed * delta

		var basis = Basis.looking_at(-directions[i], Vector3.UP)
		multimesh.set_instance_transform(i, Transform3D(basis, positions[i]))


func _get_boid_steering(index: int) -> Vector3:
	var separation = Vector3.ZERO
	var alignment = Vector3.ZERO
	var cohesion = Vector3.ZERO
	var neighbor_count = 0

	for j in range(fish_count):
		if j == index:
			continue
		var dist = positions[index].distance_to(positions[j])
		if dist < school_radius:
			neighbor_count += 1
			alignment += directions[j]
			cohesion += positions[j]
			if dist < separation_distance:
				separation += (positions[index] - positions[j]) / max(dist, 0.01)

	if neighbor_count == 0:
		return (home_position - positions[index]).normalized() * 0.3

	alignment /= neighbor_count
	cohesion = (cohesion / neighbor_count - positions[index])

	var home_pull = (home_position - positions[index]) * 0.05

	return (separation * 2.0 + alignment * 0.5 + cohesion.normalized() * 0.3 + home_pull).normalized()
