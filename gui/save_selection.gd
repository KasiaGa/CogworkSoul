extends Control

var is_loading: bool = false
var starting_level_path: String = "res://world/main.tscn"
var loading_screen_path: String = "res://cutscenes/loading_screen.tscn"
var overlay_tweens: Dictionary = {}

func _ready() -> void:
	refresh_slots()
	# Connect click and hover signals for all slots
	for i in range(1, 6):
		var slot_rect = $SlotContainer.get_node("Slot%d" % i)
		slot_rect.gui_input.connect(_on_slot_clicked.bindv([i]))
		slot_rect.mouse_entered.connect(_on_slot_hover_enter.bindv([i]))
		slot_rect.mouse_exited.connect(_on_slot_hover_exit.bindv([i]))

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
		var delete_label = slot_info.get_node("DeleteLabel")
		var new_game_label = slot_panel.get_node("NewGameLabel")
		var overlay = slot_panel.get_node("HoverOverlay")
		
		# Ensure overlay renders on top of everything else in the slot panel
		slot_panel.move_child(overlay, slot_panel.get_child_count() - 1)
		
		# Ensure overlay starts with 0 alpha and doesn't block mouse
		overlay.modulate.a = 0.0
		overlay.visible = false
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var slot_meta = slots[i - 1]
		if slot_meta["exists"]:
			var playtime_str = format_playtime(slot_meta.get("playtime", 0.0))
			slot_number_label.text = str(i)
			location_label.text = Global.get_location_name(slot_meta.get("scene", ""))
			playtime_label.text = playtime_str
			delete_label.visible = true
			new_game_label.visible = false
			
			# Try to load location image first, then fallback to thumbnail
			var location_image = Global.get_location_image(slot_meta.get("scene", ""))
			if location_image != "" and ResourceLoader.exists(location_image):
				var tex = load(location_image)
				if tex:
					texture_rect.texture = tex
			else:
				# Fallback to thumbnail if location image doesn't exist
				var thumb_path = slot_meta.get("thumbnail", "")
				if thumb_path != "" and ResourceLoader.exists(thumb_path):
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

func _on_slot_hover_enter(slot: int) -> void:
	var slot_panel = $SlotContainer.get_node("Slot%d" % slot)
	var overlay = slot_panel.get_node("HoverOverlay")
	
	# Kill any ongoing tween for this slot to avoid conflicts
	if overlay_tweens.has(slot) and overlay_tweens[slot] and overlay_tweens[slot].is_valid():
		overlay_tweens[slot].kill()
		
	overlay.visible = true
	var tween = create_tween()
	overlay_tweens[slot] = tween
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2) # Fades in over 0.2 seconds

func _on_slot_hover_exit(slot: int) -> void:
	var slot_panel = $SlotContainer.get_node("Slot%d" % slot)
	var overlay = slot_panel.get_node("HoverOverlay")
	
	# Kill any ongoing tween for this slot
	if overlay_tweens.has(slot) and overlay_tweens[slot] and overlay_tweens[slot].is_valid():
		overlay_tweens[slot].kill()
		
	var tween = create_tween()
	overlay_tweens[slot] = tween
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2) # Fades out over 0.2 seconds
	tween.tween_callback(func(): overlay.visible = false) # Hide completely after fade-out

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
