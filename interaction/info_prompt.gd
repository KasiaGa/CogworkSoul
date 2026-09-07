# InfoPrompt.gd - Simple text-only prompt with close button
extends Control

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $PanelContainer/VBoxContainer/BodyLabel
#@onready var close_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/CloseButton
@onready var panel_container: PanelContainer = $PanelContainer

func setup(title: String, text: String) -> void:
	if not is_node_ready():
		await ready

	title_label.text = title
	body_label.text = text

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_container.modulate.a = 0.9
	panel_container.self_modulate.a = 0.9
	get_tree().paused = true
	
#	close_button.pressed.connect(_on_close_pressed)
#	close_button.grab_focus()

func _on_close_pressed() -> void:
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()
