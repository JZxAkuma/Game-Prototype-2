extends CharacterBody3D
#const MAX_SPEED = 2.0
#const SPEED = 0.1
#@export var rotation_speed: float = 8.0
#@export var facing_deadzone: float = 0.05
#
#@onready var boat = $MeshInstance3D
#var mesh_facing: float
#
#func _ready() -> void:
	#mesh_facing = boat.rotation.y
#
#func _physics_process(delta: float) -> void:
	#var input_dir := Input.get_vector("boat left","boat right","boat up","boat down").normalized()
#
	#
	#if input_dir.x != 0.0:
		#velocity.x += input_dir.x * SPEED
		#velocity.x = clamp(velocity.x, -MAX_SPEED, MAX_SPEED)
	#else:
		#velocity.x = move_toward(velocity.x, 0, 0.1)
#
#
	#if input_dir.y != 0.0:
		#velocity.z += input_dir.y * SPEED
		#velocity.z = clamp(velocity.z, -MAX_SPEED, MAX_SPEED)
	#else:
		#velocity.z = move_toward(velocity.z, 0, 0.1)
#
	#var horizontal_speed = Vector2(velocity.x, velocity.z).length()
	#if horizontal_speed > facing_deadzone:
		#mesh_facing = atan2(-velocity.x, -velocity.z)
#
	#var t = 1.0 - exp(-rotation_speed * delta)
	#boat.rotation.y = lerp_angle(boat.rotation.y, mesh_facing, t)
#
	#move_and_slide()
