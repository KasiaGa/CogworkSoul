extends Control

const BUTTON_DECORATOR_SCRIPT = preload("res://gui/menu_button_decorator.gd")

const GALLERY_IMAGES = [
	preload("res://gui/loading_animation1.png"),
	preload("res://gui/loading_animation2.png"),
	preload("res://gui/loading_animation3.png")
]
const GALLERY_DESCRIPTIONS = [
	"Opening cutscene — first still.",
	"Opening cutscene — second still.",
	"Opening cutscene — final still."
]

var current_image_index: int = 0
var artwork: TextureRect
var description_label: Label
var image_counter: Label

func _ready() -> void:
	var menu_font := SystemFont.new()
	menu_font.font_names = PackedStringArray(["Palatino Linotype"])
	menu_font.font_weight = 900
	var menu_theme := Theme.new()
	menu_theme.default_font = menu_font
	theme = menu_theme
	_build_gallery()
	_show_current_image()

func _build_gallery() -> void:
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	artwork = TextureRect.new()
	artwork.anchor_right = 1.0
	artwork.anchor_bottom = 0.78
	artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	artwork.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(artwork)

	var footer_background := ColorRect.new()
	footer_background.anchor_top = 0.78
	footer_background.anchor_right = 1.0
	footer_background.anchor_bottom = 1.0
	footer_background.color = Color(0.035, 0.035, 0.045, 1.0)
	footer_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(footer_background)

	var footer := VBoxContainer.new()
	footer.anchor_top = 0.78
	footer.anchor_right = 1.0
	footer.anchor_bottom = 1.0
	footer.offset_left = 40.0
	footer.offset_top = 12.0
	footer.offset_right = -40.0
	footer.offset_bottom = -12.0
	footer.add_theme_constant_override("separation", 8)
	add_child(footer)

	var heading_row := HBoxContainer.new()
	footer.add_child(heading_row)
	var heading := Label.new()
	heading.text = "EXTRAS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading_row.add_child(heading)
	image_counter = Label.new()
	image_counter.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	image_counter.add_theme_font_size_override("font_size", 20)
	heading_row.add_child(image_counter)

	description_label = Label.new()
	description_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	description_label.add_theme_font_size_override("font_size", 18)
	footer.add_child(description_label)

	var navigation_row := HBoxContainer.new()
	footer.add_child(navigation_row)
	var back_button := Button.new()
	back_button.text = "Back to menu"
	back_button.custom_minimum_size = Vector2(250.0, 42.0)
	_apply_main_menu_button_style(back_button)
	back_button.pressed.connect(_on_back_pressed)
	navigation_row.add_child(back_button)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	navigation_row.add_child(spacer)
	var previous_button := Button.new()
	previous_button.text = "Previous"
	previous_button.custom_minimum_size = Vector2(130.0, 42.0)
	previous_button.pressed.connect(_on_previous_pressed)
	navigation_row.add_child(previous_button)
	var next_button := Button.new()
	next_button.text = "Next"
	next_button.custom_minimum_size = Vector2(130.0, 42.0)
	next_button.pressed.connect(_on_next_pressed)
	navigation_row.add_child(next_button)

func _apply_main_menu_button_style(button: Button) -> void:
	var decorator = BUTTON_DECORATOR_SCRIPT.new()
	decorator.edge_inset = 10.0
	button.add_child(decorator)

func _show_current_image() -> void:
	artwork.texture = GALLERY_IMAGES[current_image_index]
	description_label.text = GALLERY_DESCRIPTIONS[current_image_index]
	image_counter.text = "%d / %d" % [current_image_index + 1, GALLERY_IMAGES.size()]

func _on_previous_pressed() -> void:
	current_image_index = (current_image_index - 1 + GALLERY_IMAGES.size()) % GALLERY_IMAGES.size()
	_show_current_image()

func _on_next_pressed() -> void:
	current_image_index = (current_image_index + 1) % GALLERY_IMAGES.size()
	_show_current_image()

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
