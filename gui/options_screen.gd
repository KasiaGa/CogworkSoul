extends Control

signal back_requested

@onready var back_button: Button = $CenterContainer/PanelContainer/MarginContainer/VBoxContainer/BackButton
var text_tweens: Dictionary = {}

func _ready() -> void:
	var empty_style := StyleBoxEmpty.new()
	for style_name in ["normal", "hover", "pressed", "focus"]:
		back_button.add_theme_stylebox_override(style_name, empty_style)
	back_button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_button.set_meta("original_text", back_button.text)
	back_button.mouse_entered.connect(_on_button_hover_enter.bind(back_button))
	back_button.mouse_exited.connect(_on_button_hover_exit.bind(back_button))
	back_button.pressed.connect(_on_back_pressed)

func set_back_label(label: String) -> void:
	back_button.text = label
	back_button.set_meta("original_text", label)

func _on_button_hover_enter(button: Button) -> void:
	var original_text: String = button.get_meta("original_text")
	button.text = "> " + original_text + " <"
	button.pivot_offset = button.size / 2
	var tween_key = button.name
	if text_tweens.has(tween_key) and text_tweens[tween_key] and text_tweens[tween_key].is_valid():
		text_tweens[tween_key].kill()
	var tween := create_tween()
	text_tweens[tween_key] = tween
	tween.tween_property(button, "scale", Vector2(1.15, 1.15), 0.2)

func _on_button_hover_exit(button: Button) -> void:
	button.text = button.get_meta("original_text")
	button.pivot_offset = button.size / 2
	var tween_key = button.name
	if text_tweens.has(tween_key) and text_tweens[tween_key] and text_tweens[tween_key].is_valid():
		text_tweens[tween_key].kill()
	var tween := create_tween()
	text_tweens[tween_key] = tween
	tween.tween_property(button, "scale", Vector2.ONE, 0.2)

func _on_back_pressed() -> void:
	back_requested.emit()