extends Control

func _ready() -> void:
	load_drawings()

func load_drawings() -> void:
	var container = $DrawingsContainer/VBoxContainer
	
	# Clear any existing drawings
	for child in container.get_children():
		child.queue_free()
	
	# Load drawings from res://assets/extras/ directory
	# You can add your drawing images there
	var extras_path = "res://assets/extras/"
	if DirAccess.dir_exists_absolute(extras_path):
		var dir = DirAccess.open(extras_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			while file_name != "":
				if not file_name.starts_with("."):
					# Check if it's an image file
					if file_name.ends_with(".png") or file_name.ends_with(".jpg") or file_name.ends_with(".jpeg"):
						var full_path = extras_path + file_name
						if ResourceLoader.exists(full_path):
							var texture = load(full_path)
							if texture:
								var img_rect = TextureRect.new()
								img_rect.texture = texture
								img_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH
								img_rect.custom_minimum_size = Vector2(800, 0)
								container.add_child(img_rect)
				file_name = dir.get_next()
	else:
		# Show placeholder if no extras folder exists
		var label = Label.new()
		label.text = "No drawings yet!\n\nAdd images to res://assets/extras/"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		container.add_child(label)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://gui/main_menu.tscn")
