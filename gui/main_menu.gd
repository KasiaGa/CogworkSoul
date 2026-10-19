extends Control

var text_tweens: Dictionary = {}
@onready var options_screen: Control = $OptionsScreen

func _ready() -> void:
	options_screen.connect("back_requested", _on_options_back)
	var buttons = [$VBoxContainer/StartButton, $VBoxContainer/ExtrasButton, $VBoxContainer/OptionsButton, $VBoxContainer/ExitButton]
	
	for btn in buttons:
		# Remove the semi-transparent background by using empty styleboxes
		var empty_style = StyleBoxEmpty.new()
		btn.add_theme_stylebox_override("normal", empty_style)
		btn.add_theme_stylebox_override("hover", empty_style)
		btn.add_theme_stylebox_override("pressed", empty_style)
		btn.add_theme_stylebox_override("focus", empty_style)
		
		# Center alignment so text expands smoothly from the middle
		btn.alignment = HORIZONTAL_ALIGNMENT_CENTER
		
		# Store original text as metadata so we can easily restore it on exit
		btn.set_meta("original_text", btn.text)
		
		# Connect hover signals dynamically
		btn.mouse_entered.connect(_on_button_hover_enter.bind(btn))
		btn.mouse_exited.connect(_on_button_hover_exit.bind(btn))

func _on_button_hover_enter(btn: Button) -> void:
	var orig_text = btn.get_meta("original_text")
	btn.text = "> " + orig_text + " <"
	btn.pivot_offset = btn.size / 2
	
	var tween_key = btn.name
	if text_tweens.has(tween_key) and text_tweens[tween_key] and text_tweens[tween_key].is_valid():
		text_tweens[tween_key].kill()
		
	var tween = create_tween()
	text_tweens[tween_key] = tween
	tween.tween_property(btn, "scale", Vector2(1.15, 1.15), 0.2)

func _on_button_hover_exit(btn: Button) -> void:
	var orig_text = btn.get_meta("original_text")
	btn.text = orig_text
	btn.pivot_offset = btn.size / 2
	
	var tween_key = btn.name
	if text_tweens.has(tween_key) and text_tweens[tween_key] and text_tweens[tween_key].is_valid():
		text_tweens[tween_key].kill()
		
	var tween = create_tween()
	text_tweens[tween_key] = tween
	tween.tween_property(btn, "scale", Vector2(1.0, 1.0), 0.2)

func _on_start_button_pressed() -> void:
	# Go to save selection to choose/create a save
	get_tree().change_scene_to_file("res://gui/save_selection.tscn")

func _on_extras_button_pressed() -> void:
	# Go to extras view
	get_tree().change_scene_to_file("res://gui/extras.tscn")

func _on_options_button_pressed() -> void:
	options_screen.call("set_back_label", "Back to menu")
	options_screen.show()

func _on_options_back() -> void:
	options_screen.hide()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
