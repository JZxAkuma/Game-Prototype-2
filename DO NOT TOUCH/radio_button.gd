extends Area3D
@onready var mesh: MeshInstance3D = $RadioButton2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	mesh.hide()
	input_event.connect(_on_input_event)
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exit)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		pass

func _on_mouse_entered() -> void:
	mesh.show()

func _on_mouse_exit() -> void:
	mesh.hide()
