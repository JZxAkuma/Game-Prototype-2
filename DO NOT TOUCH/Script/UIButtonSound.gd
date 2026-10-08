extends Control

@onready var click_sound = $UIClickSound

func _ready():
	for button in get_tree().get_nodes_in_group("ui_buttons"):
		button.pressed.connect(play_click_sound)

func play_click_sound():
	click_sound.play()
