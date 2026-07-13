# location_banner.gd
extends CanvasLayer

@onready var label: Label = $CenterContainer/MarginContainer/VBoxContainer/Label
@onready var sprite2d: Sprite2D = $CenterContainer/MarginContainer/VBoxContainer/Sprite2D

func display_title(location_name: String) -> void:
	label.text = location_name
	
	# Set starting transparency
	label.modulate.a = 0.0
	sprite2d.modulate.a = 0.0
	
	var tween = create_tween()
	
	# --- FADE IN TOGETHER ---
	tween.tween_property(label, "modulate:a", 1.0, 1.0)
	tween.parallel().tween_property(sprite2d, "modulate:a", 1.0, 1.0) # Runs alongside label fade!
	
	# Hold on screen (2 seconds)
	tween.tween_interval(2.0)
	
	# --- FADE OUT TOGETHER ---
	tween.tween_property(label, "modulate:a", 0.0, 1.0)
	tween.parallel().tween_property(sprite2d, "modulate:a", 0.0, 1.0) # Runs alongside label fade!
	
	# Clean up after everything finishes
	await tween.finished
	queue_free()
