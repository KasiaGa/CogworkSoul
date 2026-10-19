extends Control

signal back_requested

@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton

func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)

func set_back_label(label: String) -> void:
	back_button.text = label

func _on_back_pressed() -> void:
	back_requested.emit()