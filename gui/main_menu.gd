extends Control

func _on_start_button_pressed() -> void:
	# Go to save selection to choose/create a save
	get_tree().change_scene_to_file("res://gui/save_selection.tscn")

func _on_extras_button_pressed() -> void:
	# Go to extras view
	get_tree().change_scene_to_file("res://gui/extras.tscn")

func _on_exit_button_pressed() -> void:
	get_tree().quit()
