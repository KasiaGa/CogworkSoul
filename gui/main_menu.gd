extends Control

const BUTTON_DECORATOR_SCRIPT = preload("res://gui/menu_button_decorator.gd")

@onready var options_screen: Control = $OptionsScreen

func _ready() -> void:
	options_screen.connect("back_requested", _on_options_back)
	var buttons = [$VBoxContainer/StartButton, $VBoxContainer/ExtrasButton, $VBoxContainer/OptionsButton, $VBoxContainer/ExitButton]
	
	for btn in buttons:
		btn.custom_minimum_size = Vector2(320.0, btn.custom_minimum_size.y)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var decorator = BUTTON_DECORATOR_SCRIPT.new()
		decorator.edge_inset = 32.0
		btn.add_child(decorator)

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
