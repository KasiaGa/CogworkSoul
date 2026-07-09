extends Control

# Update this path to match your actual starting level scene!
const STARTING_LEVEL_PATH = "res://world/main.tscn"

func _on_start_button_pressed() -> void:
	# RESET GLOBAL DATA FOR A FRESH NEW GAME
	Global.player_max_health = 5
	Global.player_current_health = 5
	Global.player_max_silk = 5
	Global.player_current_silk = 0
	Global.has_needle = false
	Global.player_is_sitting = false
	Global.collected_items.clear()
	Global.intro_dialogue_played = false
	Global.should_reposition = false
	Global.target_position = Vector2.ZERO
	
	# Boot into the first room of the game
	get_tree().change_scene_to_file(STARTING_LEVEL_PATH)


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
