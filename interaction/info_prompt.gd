# InfoPrompt.gd - Simple text-only prompt, dismissed with Enter/Space
extends Control

@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $PanelContainer/VBoxContainer/BodyLabel
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

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_close()
			get_tree().root.set_input_as_handled()

func _close() -> void:
	get_tree().paused = false
	queue_free()
