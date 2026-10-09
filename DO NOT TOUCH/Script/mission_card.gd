extends Control


signal accept_pressed(mission: Mission)

@onready var name_label: Label = $VBoxContainer/namelabel
@onready var desc_label: Label = $VBoxContainer/Desclabel
@onready var type_label: Label = $"VBoxContainer/Type label"
@onready var sector_label: Label = $VBoxContainer/Sector
@onready var accept_button: Button = $VBoxContainer/acceptbutton


var mission: Mission


func setup(m: Mission) -> void:
	mission = m
	name_label.text = m.mission_name
	desc_label.text = m.description
	type_label.text = "Type: " + Mission.Type.keys()[m.type]
	sector_label.text = "" 


func _ready() -> void:
	accept_button.pressed.connect(_on_accept_pressed)


func _on_accept_pressed() -> void:
	accept_button.hide()
	accept_pressed.emit(mission)
