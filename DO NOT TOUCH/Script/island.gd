extends Area3D

@export var underwater_scene : PackedScene
@export var fallback_scene_path: String = "res://DO NOT TOUCH/world.tscn"
@export var highlight_material:Material

@onready var mesh = $MeshInstance3D2
var base_material : Material
@onready var marker = $CameraMarker

var overworld

var focused_on = false
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	overworld = get_parent()
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exit)
	#base_material  = mesh.material
	mesh.hide()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if overworld.has_method("_focus"):
			#mesh.hide()
			overworld._focus(self, marker)

func _on_mouse_entered() -> void:
	if !overworld.focusing:
		mesh.show()

func _on_mouse_exit() -> void:
	if !focused_on:
		mesh.hide()

func _get_underwater_scene() -> PackedScene:
	if underwater_scene:
		return underwater_scene
	
	if fallback_scene_path:
		var loaded = load(fallback_scene_path)
		if loaded is PackedScene:
			return loaded
		else:
			push_warning("SectorButton '%s': fallback_scene_path did not resolve to a PackedScene: %s" % [name, fallback_scene_path])
			return null

	push_warning("SectorButton '%s': no underwater_scene assigned and no fallback_scene_path set" % name)
	return null
