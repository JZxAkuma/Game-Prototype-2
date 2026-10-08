extends Control

signal retry_pressed
signal submit_pressed

@onready var photo_display: TextureRect = $VBoxContainer/TextureRect2/TextureRect/TextureRect3
@onready var retry_button: Button = $VBoxContainer/HBoxContainer/Button
@onready var submit_button: Button = $VBoxContainer/HBoxContainer/Button2


func _ready() -> void:
	retry_button.pressed.connect(func(): retry_pressed.emit())
	submit_button.pressed.connect(func(): submit_pressed.emit())
	hide()


func show_review(img: Image) -> void:
	var tex = ImageTexture.create_from_image(img)
	photo_display.texture = tex
	show()


func hide_review() -> void:
	hide()
