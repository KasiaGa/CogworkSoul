extends CanvasLayer

@onready var resume_button: Button = $ColorRect/CenterContainer/VBoxContainer/Resume
@onready var quit_button: Button = $"ColorRect/CenterContainer/VBoxContainer/Quit to Main Menu"
@onready var options_button: Button = $ColorRect/CenterContainer/VBoxContainer/Options
@onready var options_screen: Control = $OptionsScreen

func _ready() -> void:
	# Hide the menu by default when the game starts
	hide()
	
	# Connect the buttons
	resume_button.pressed.connect(_on_resume_pressed)
	options_button.pressed.connect(_on_options_pressed)
	quit_button.pressed.connect(_on_quit_pressed)
	options_screen.connect("back_requested", _on_options_back)

#func _input(event: InputEvent) -> void:
#	# Check if the player pressed the Escape key
#	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("menu_esc"):
#		if visible:
#			resume_game()
#		else:
#			pause_game()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("menu_esc") or Input.is_action_just_pressed("ui_cancel"):
		if visible:
			resume_game()
		else:
			pause_game()

func pause_game() -> void:
	options_screen.hide()
	show()
	get_tree().paused = true

func resume_game() -> void:
	options_screen.hide()
	hide()
	get_tree().paused = false

func _on_resume_pressed() -> void:
	resume_game()

func _on_options_pressed() -> void:
	options_screen.call("set_back_label", "Back to game")
	options_screen.show()

func _on_options_back() -> void:
	resume_game()

func _on_quit_pressed() -> void:
	# Unpause the engine tree before switching scenes so the main menu isn't frozen
	get_tree().paused = false
	# Change this path to your actual main menu scene location!
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
