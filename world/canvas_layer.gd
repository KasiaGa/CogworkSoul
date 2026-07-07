extends CanvasLayer

@onready var notification_box: PanelContainer = $NotificationBox
@onready var notification_label: Label = $NotificationBox/NotificationLabel

var active_tween: Tween

func _ready() -> void:
	# Double check that it starts completely invisible
	notification_box.modulate.a = 0.0

func show_notification(text: String) -> void:
	# Update the label text dynamically
	notification_label.text = text
	
	# If a notification is already running, cancel it so they don't fight
	if active_tween:
		active_tween.kill()
		
	# Create a brand new fluid animation sequence
	active_tween = create_tween()
	
	# 1. Fade IN over 0.2 seconds
	active_tween.tween_property(notification_box, "modulate:a", 1.0, 0.2)
	
	# 2. HOLD visible for 2.0 seconds
	active_tween.tween_interval(2.0)
	
	# 3. Fade OUT over 0.4 seconds
	active_tween.tween_property(notification_box, "modulate:a", 0.0, 0.4)
