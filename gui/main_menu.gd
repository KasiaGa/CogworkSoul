extends Control

# Update this path to match your actual starting level scene!
const STARTING_LEVEL_PATH = "res://world/main.tscn"

func _on_start_button_pressed() -> void:
	# Load the loading screen first, which will preload all cutscene frames
	# Then it will transition to the cutscene
	get_tree().change_scene_to_file("res://cutscenes/loading_screen.tscn")


func _on_load_button_pressed() -> void:
	# Call the load function we wrote earlier. 
	# It automatically shifts scenes and repositions the player if a save exists.
	var load_successful = Global.load_game()
	
	if not load_successful:
		# Optional: You could make a text flash here saying "No Save Found!"
		print("Could not load game - file missing!")


func _on_exit_button_pressed() -> void:
	# Safely closes the game application window
	get_tree().quit()
