extends Control

const BUTTON_DECORATOR_SCRIPT = preload("res://gui/menu_button_decorator.gd")

signal back_requested

@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	var decorator = BUTTON_DECORATOR_SCRIPT.new()
	decorator.edge_inset = 10.0
	back_button.add_child(decorator)
	back_button.pressed.connect(_on_back_pressed)

func set_back_label(label: String) -> void:
	back_button.text = label

func _on_back_pressed() -> void:
	back_requested.emit()