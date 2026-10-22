extends CanvasLayer

@onready var label: Label = $Label

func display_title(region_name: String) -> void:
	label.text = region_name
	label.modulate.a = 0.0

	var tween := create_tween()
	tween.tween_property(label, "modulate:a", 1.0, 0.4)
	tween.tween_interval(2.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
	await tween.finished
	queue_free()