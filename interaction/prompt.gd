# Prompt.gd
extends Control

signal response_selected(confirmed: bool)

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $PanelContainer/VBoxContainer/BodyLabel
@onready var sprite_2d: Sprite2D = $PanelContainer/VBoxContainer/MarginContainer/Sprite2D
@onready var yes_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/NoButton

func setup(title: String, prompt_question: String, icon_texture: Texture2D = null) -> void:
	if not is_node_ready():
		await ready

	title_label.text = title
	body_label.text = prompt_question
	
	if icon_texture and sprite_2d:
		sprite_2d.texture = icon_texture
		sprite_2d.visible = true
	elif sprite_2d:
		sprite_2d.visible = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel_container.modulate.a = 0.9
	panel_container.self_modulate.a = 0.9
	get_tree().paused = true
	
	# Layout safety setup
#	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
#	if panel_container:
#		panel_container.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	
	yes_button.grab_focus()

func _on_yes_pressed() -> void:
	response_selected.emit(true)
	_close()

func _on_no_pressed() -> void:
	response_selected.emit(false)
	_close()

func _close() -> void:
	get_tree().paused = false
	queue_free()
