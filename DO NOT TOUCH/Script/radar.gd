extends Control

@export var tracked_group: String = "photographable"
@export var radar_range: float = 50.0
@export var blip_color: Color = Color(0.2, 1.0, 0.3)
@export var blip_size: float = 6.0
@export var blink_speed: float = 4.0

@export var player_dot_color: Color = Color(1.0, 1.0, 1.0)
@export var player_dot_size: float = 8.0

@export var player_path: NodePath
@onready var player: Node3D = get_node(player_path)
@onready var player_dot: ColorRect = ColorRect.new()

var blips: Array[ColorRect] = []
var blink_time: float = 0.0


func _ready() -> void:
	player_dot.color = player_dot_color
	player_dot.size = Vector2(player_dot_size, player_dot_size)
	add_child(player_dot)
	_position_player_dot()


func _process(delta: float) -> void:
	blink_time += delta * blink_speed
	_update_blips()


func _position_player_dot() -> void:
	var center = size / 2.0
	player_dot.position = center - Vector2(player_dot_size, player_dot_size) / 2.0


func _update_blips() -> void:
	for b in blips:
		b.queue_free()
	blips.clear()

	var radar_size = size
	var center = radar_size / 2.0
	var max_radius = radar_size.x / 2.0

	var tracked = get_tree().get_nodes_in_group(tracked_group)
	var blink_alpha = (sin(blink_time) + 1.0) / 2.0

	var sub_yaw = player.rotation.y

	for obj in tracked:
		var relative = obj.global_position - player.global_position
		var flat = Vector2(relative.x, relative.z)
		flat = flat.rotated(sub_yaw)

		var dist = flat.length()
		var normalized = flat / radar_range
		if normalized.length() > 1.0:
			normalized = normalized.normalized()

		var radar_pos = center + normalized * max_radius
		_place_blip(radar_pos, blink_alpha)


func _place_blip(pos: Vector2, alpha: float) -> void:
	var blip = ColorRect.new()
	var c = blip_color
	c.a = alpha
	blip.color = c
	blip.size = Vector2(blip_size, blip_size)
	blip.position = pos - Vector2(blip_size, blip_size) / 2.0
	add_child(blip)
	blips.append(blip)
