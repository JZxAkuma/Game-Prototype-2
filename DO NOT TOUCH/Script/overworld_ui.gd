extends CanvasLayer

var overworld
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	overworld = get_parent()


# Called every frame. 'delta' is the elapsed time since the previous frame.
#func _process(delta: float) -> void:
	#pass


func _on_back_button_pressed() -> void:
	overworld._unfocus()


func _on_dive_button_pressed() -> void:
	overworld._dive()
