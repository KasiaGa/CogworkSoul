extends Control

const BUTTON_DECORATOR_SCRIPT = preload("res://gui/menu_button_decorator.gd")

var is_loading: bool = false
var starting_level_path: String = "res://world/main.tscn"
var loading_screen_path: String = "res://cutscenes/loading_screen.tscn"
var overlay_tweens: Dictionary = {}

func _ready() -> void:
	refresh_slots()
	
	# Connect click and hover signals for all slots
	for i in range(1, 6):
		var slot_panel = $SlotContainer.get_node("Slot%d" % i)
		slot_panel.gui_input.connect(_on_slot_clicked.bindv([i]))
		slot_panel.mouse_entered.connect(_on_slot_hover_enter.bindv([i]))
		slot_panel.mouse_exited.connect(_on_slot_hover_exit.bindv([i]))
		
		# Allow mouse events to pass through SlotInfo to the panel, 
		# but keep DeleteLabel interactive and add hover effects
		var slot_info = slot_panel.get_node("SlotInfo")
		slot_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
		
		var delete_label = slot_info.get_node("DeleteLabel")
		delete_label.mouse_filter = Control.MOUSE_FILTER_STOP
		delete_label.gui_input.connect(_on_delete_clicked.bindv([i]))
		var delete_decorator = BUTTON_DECORATOR_SCRIPT.new()
		delete_decorator.edge_inset = 32.0
		delete_label.add_child(delete_decorator)

	var back_decorator = BUTTON_DECORATOR_SCRIPT.new()
	back_decorator.edge_inset = 28.0
	$BackButton.add_child(back_decorator)

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
			
			texture_rect.texture = null
			var preview_paths = [
				str(slot_meta.get("bench_preview_path", "")),
				Global.NO_BENCH_PREVIEW_IMAGE_PATH
			]
			for preview_path in preview_paths:
				if preview_path.is_empty() or not ResourceLoader.exists(preview_path):
					continue
				var preview_texture = load(preview_path)
				if preview_texture:
					texture_rect.texture = preview_texture
					break
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
	
	if overlay_tweens.has(slot) and overlay_tweens[slot] and overlay_tweens[slot].is_valid():
		overlay_tweens[slot].kill()
		
	overlay.visible = true
	var tween = create_tween()
	overlay_tweens[slot] = tween
	tween.tween_property(overlay, "modulate:a", 1.0, 0.2)

func _on_slot_hover_exit(slot: int) -> void:
	var slot_panel = $SlotContainer.get_node("Slot%d" % slot)
	var overlay = slot_panel.get_node("HoverOverlay")
	
	if overlay_tweens.has(slot) and overlay_tweens[slot] and overlay_tweens[slot].is_valid():
		overlay_tweens[slot].kill()
		
	var tween = create_tween()
	overlay_tweens[slot] = tween
	tween.tween_property(overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(func(): overlay.visible = false)

func _on_slot_clicked(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		_on_slot_selected(slot)

func _on_delete_clicked(event: InputEvent, slot: int) -> void:
	if event is InputEventMouseButton and event.pressed:
		get_viewport().set_input_as_handled()
		_on_delete_pressed(slot)

func _on_slot_selected(slot: int) -> void:
	Global.set_current_slot(slot)
	
	var slots = Global.get_save_slots()
	var slot_meta = slots[slot - 1]
	
	if slot_meta["exists"]:
		Global.load_game(slot)
	else:
		get_tree().change_scene_to_file(loading_screen_path)

func _on_delete_pressed(slot: int) -> void:
	Global.delete_save(slot)
	refresh_slots()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
