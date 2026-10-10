extends Control

var effect_time: float = 0.0

func _process(delta: float) -> void:
	effect_time += delta
	queue_redraw()

func _draw() -> void:
	var size = get_viewport_rect().size
	if size.x <= 0 or size.y <= 0:
		return
		
	# Draw moving light rays/shadow streaks using thick lines
	for i in range(4):
		var speed = 40.0 + (i * 15.0)
		var offset = fmod(effect_time * speed + (i * 300.0), size.x + size.y)
		
		var start_point = Vector2(offset, -50)
		var end_point = Vector2(offset - size.y - 150, size.y + 50)
		
		# Alternate between a faint light tint and shadow tint, with a width of 120 pixels
		var color = Color(1.0, 1.0, 1.0, 0.03) if i % 2 == 0 else Color(0.0, 0.0, 0.0, 0.05)
		draw_line(start_point, end_point, color, 120.0)
