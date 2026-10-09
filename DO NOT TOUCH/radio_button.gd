extends Area3D

@export var hold_time: float = 0.5 

@onready var mesh: MeshInstance3D = $RadioButton2

var pressing: bool = false
var press_timer: float = 0.0
var hold_fired: bool = false


func _ready() -> void:
	mesh.hide()


func hover_enter() -> void:
	mesh.show()


func hover_exit() -> void:
	mesh.hide()
	_reset()  

func interact() -> void:
	pressing = true
	press_timer = 0.0
	hold_fired = false


func _process(delta: float) -> void:
	if not pressing:
		return

	if Input.is_action_pressed("interact"):
		press_timer += delta
		if not hold_fired and press_timer >= hold_time:
			hold_fired = true
			MusicPlayer.stop()
	else:
		# released
		if not hold_fired:
			_short_click()
		_reset()


func _short_click() -> void:
	if MusicPlayer.running and not MusicPlayer.paused:
		MusicPlayer.next_song()
	else:
		MusicPlayer.start() 


func _reset() -> void:
	pressing = false
	press_timer = 0.0
	hold_fired = false
