extends CanvasLayer

var panel_root: Control
var state_editor: TextEdit
var status_label: Label

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	_build_panel()
	panel_root.hide()

func is_open() -> bool:
	return panel_root != null and panel_root.visible

func open_panel() -> void:
	_refresh_state_text()
	panel_root.show()

func close_panel() -> void:
	panel_root.hide()

func _build_panel() -> void:
	panel_root = Control.new()
	panel_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel_root)

	var backdrop := ColorRect.new()
	backdrop.color = Color(0.0, 0.0, 0.0, 0.78)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	panel_root.add_child(backdrop)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -470.0
	panel.offset_top = -340.0
	panel.offset_right = 470.0
	panel.offset_bottom = 340.0
	panel_root.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	margin.add_child(layout)

	var heading := Label.new()
	heading.text = "DEBUG SAVE STATE"
	heading.add_theme_font_size_override("font_size", 24)
	layout.add_child(heading)

	var instructions := Label.new()
	instructions.text = "Edit the JSON below, then choose Apply & Save. It lists all persistent save values; saved_at is generated automatically. Health/silk update live, while scene-specific values apply when that scene loads. Close the panel when finished."
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(instructions)

	state_editor = TextEdit.new()
	state_editor.custom_minimum_size = Vector2(900.0, 500.0)
	state_editor.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(state_editor)

	status_label = Label.new()
	status_label.text = ""
	layout.add_child(status_label)

	var buttons := HBoxContainer.new()
	layout.add_child(buttons)
	var apply_button := Button.new()
	apply_button.text = "Apply & Save"
	apply_button.pressed.connect(_on_apply_pressed)
	buttons.add_child(apply_button)
	var refresh_button := Button.new()
	refresh_button.text = "Reload Current Values"
	refresh_button.pressed.connect(_refresh_state_text)
	buttons.add_child(refresh_button)
	var close_button := Button.new()
	close_button.text = "Close"
	close_button.pressed.connect(Global.close_debug_state_panel)
	buttons.add_child(close_button)

func _refresh_state_text() -> void:
	state_editor.text = JSON.stringify(Global.get_debug_save_state(), "\t")
	status_label.text = "Editing save slot %d. Changes are not saved until Apply & Save." % Global.current_slot

func _on_apply_pressed() -> void:
	var parser := JSON.new()
	var parse_error := parser.parse(state_editor.text)
	if parse_error != OK:
		status_label.text = "JSON error on line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		return
	if typeof(parser.data) != TYPE_DICTIONARY:
		status_label.text = "The JSON root must be an object/dictionary."
		return
	var error_message := Global.apply_debug_save_state(parser.data)
	if error_message.is_empty():
		status_label.text = "Applied and saved to slot %d." % Global.current_slot
	else:
		status_label.text = error_message