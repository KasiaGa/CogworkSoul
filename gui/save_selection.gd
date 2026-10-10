extends Control

var is_loading: bool = false
var starting_level_path: String = "res://world/main.tscn"
var loading_screen_path: String = "res://cutscenes/loading_screen.tscn"

func _ready() -> void:
	refresh_slots()
	# Connect click signals for all slots
	for i in range(1, 6):
		var slot_rect = $SlotContainer.get_node("Slot%d" % i)
		slot_rect.gui_input.connect(_on_slot_clicked.bindv([i]))

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
		var texture_rect = slot_panel.get_node("TextureRect")
		var slot_info = slot_panel.get_node("SlotInfo")
		var slot_number_label = slot_info.get_node("SlotNumber")
		var location_label = slot_info.get_node("LocationName")
		var playtime_label = slot_info.get_node("PlaytimeLabel")
		var delete_label = slot_panel.get_node("DeleteLabel")
		var new_game_label = slot_panel.get_node("NewGameLabel")
		
		var slot_meta = slots[i - 1]
		if slot_meta["exists"]:
			var playtime_str = format_playtime(slot_meta.get("playtime", 0.0))
			slot_number_label.text = str(i)
			location_label.text = slot_meta.get("scene", "")
			playtime_label.text = playtime_str
			delete_label.visible = true
			new_game_label.visible = false
			
			# Try to load and display thumbnail
			var thumb_path = slot_meta.get("thumbnail", "")
			if thumb_path != "":
				if ResourceLoader.exists(thumb_path):
					var tex = load(thumb_path)
					if tex:
						texture_rect.texture = tex
			slot_info.visible = true
		else:
			slot_number_label.text = str(i)
			location_label.text = ""
			playtime_label.text = ""
			delete_label.visible = false
			new_game_label.visible = true
			texture_rect.texture = null
			slot_info.visible = false

func _on_slot_clicked(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_slot_selected(slot)

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

func _on_delete_pressed(slot: int) -> void:
	Global.delete_save(slot)
	refresh_slots()

func _on_back_pressed() -> void:
	# Return to main menu
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
