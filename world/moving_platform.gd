extends AnimatableBody2D

@export var move_distance: float = 300.0  # Distance in pixels to move (positive = down, negative = up)
@export var move_time: float = 2.0        # Seconds it takes to reach target position
@export var wait_time: float = 0.5        # Seconds to wait before turning back
@export var start_delay: float = 0.0      # Delay before this platform starts its loop
@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

var start_position: Vector2

func _ready() -> void:
	animation.play("default")
	start_position = position
	
	if start_delay > 0.0:
		get_tree().create_timer(start_delay).timeout.connect(start_moving)
	else:
		start_moving()


func start_moving() -> void:
	var target_position = start_position + Vector2(0, move_distance)

	# Create a continuous looping Tween
	var tween = create_tween().set_loops()
	
	# Move to target position
	tween.tween_property(self, "position", target_position, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
	
	# Move back to start position
	tween.tween_property(self, "position", start_position, move_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_interval(wait_time)
