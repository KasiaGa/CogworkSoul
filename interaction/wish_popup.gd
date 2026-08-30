# WishPopup.gd
extends Control

signal response_selected(accepted: bool, wish_id: String)

@onready var panel_container: PanelContainer = $PanelContainer
@onready var title_label: Label = $PanelContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $PanelContainer/VBoxContainer/BodyLabel
@onready var yes_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/YesButton
@onready var no_button: Button = $PanelContainer/VBoxContainer/HBoxContainer/NoButton
@onready var fade_overlay: ColorRect = $FadeOverlay
@onready var sprite_overlay: Sprite2D = $SpriteOverlay
@onready var text_overlay: Label = $TextOverlay

var wish_id: String = ""
var wish_display_name: String = ""
var is_waiting_for_confirm: bool = false

func setup(id: String, display_name: String, prompt_text: String = "Accept wish?") -> void:
	wish_id = id
	wish_display_name = display_name
	
	# Make sure nodes are ready before setting text if called right after instantiate()
	if not is_node_ready():
		await ready

	title_label.text = wish_display_name
	body_label.text = prompt_text
	text_overlay.text = "%s\nWish Accepted" % wish_display_name

func _ready() -> void:
	# Keep this UI processing even when the game tree is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	panel_container.modulate.a = 0.9
	panel_container.self_modulate.a = 0.9
	
	# Pause movement and game world interactions
	get_tree().paused = true

	fade_overlay.color = Color(0, 0, 0, 0)
	fade_overlay.visible = false
	text_overlay.visible = false
	text_overlay.modulate.a = 1.0
	sprite_overlay.visible = false
	
	yes_button.pressed.connect(_on_yes_pressed)
	no_button.pressed.connect(_on_no_pressed)
	
	yes_button.grab_focus()

func _input(event: InputEvent) -> void:
	if is_waiting_for_confirm and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_fade_out_and_close()

func _on_yes_pressed() -> void:
	response_selected.emit(true, wish_id)
	
	panel_container.visible = false
	fade_overlay.visible = true
	text_overlay.visible = true
	sprite_overlay.visible = true
	
	var tween = create_tween()
	tween.tween_property(fade_overlay, "color:a", 1.0, 0.6)
	await tween.finished
	
	is_waiting_for_confirm = true

func _on_no_pressed() -> void:
	response_selected.emit(false, wish_id)
	_cleanup_and_unpause()

func _fade_out_and_close() -> void:
	is_waiting_for_confirm = false
	
	var tween = create_tween().set_parallel(true)
	tween.tween_property(fade_overlay, "color:a", 0.0, 0.5)
	tween.tween_property(text_overlay, "modulate:a", 0.0, 0.5)
	tween.tween_property(sprite_overlay, "modulate:a", 0.0, 0.5)
	await tween.finished
	
	_cleanup_and_unpause()

func _cleanup_and_unpause() -> void:
	get_tree().paused = false
	queue_free()
