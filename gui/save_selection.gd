extends Control

var is_loading: bool = false
var starting_level_path: String = "res://world/main.tscn"
var loading_screen_path: String = "res://cutscenes/loading_screen.tscn"

func _ready() -> void:
	refresh_slots()

func format_playtime(seconds: float) -> String:
	var total_seconds = int(seconds)
	var hours = total_seconds / 3600
	var minutes = (total_seconds % 3600) / 60
	var secs = total_seconds % 60
	return "%02d:%02d:%02d" % [hours, minutes, secs]

func refresh_slots() -> void:
	var slots = Global.get_save_slots()
	for i in range(1, 6):
		var slot_panel = $SlotContainer.get_node("Slot%d" % i)
		var vbox = slot_panel.get_node("VBoxContainer")
		var texture_rect = vbox.get_node("TextureRect")
		var label = vbox.get_node("Label")
		var button_container = vbox.get_node("ButtonContainer")
		var select_button = button_container.get_node("SelectButton")
		var delete_button = button_container.get_node("DeleteButton")
		
		var slot_meta = slots[i - 1]
		if slot_meta["exists"]:
			var playtime_str = format_playtime(slot_meta.get("playtime", 0.0))
			label.text = "Slot %d\n%s\n%s" % [i, slot_meta.get("scene", ""), playtime_str]
			select_button.text = "Continue" if is_loading else "Load"
			delete_button.disabled = false
			
			# Try to load and display thumbnail
			var thumb_path = slot_meta.get("thumbnail", "")
			if thumb_path != "":
				if ResourceLoader.exists(thumb_path):
					var tex = load(thumb_path)
					if tex:
						texture_rect.texture = tex
		else:
			label.text = "Slot %d\nNew Game" % i
			select_button.text = "Start" if not is_loading else "New"
			delete_button.disabled = true
			texture_rect.texture = null

func _on_slot_selected(slot: int) -> void:
	Global.set_current_slot(slot)
	
	var slots = Global.get_save_slots()
	var slot_meta = slots[slot - 1]
	
	if slot_meta["exists"]:
		# Load existing save
		Global.load_game(slot)
	else:
		# Start new game in this slot - go through loading screen for cutscene
		get_tree().change_scene_to_file(loading_screen_path)

func _on_slot_deleted(slot: int) -> void:
	Global.delete_save(slot)
	refresh_slots()

func _on_back_pressed() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
