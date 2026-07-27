extends AnimatableBody2D

@export var belt_speed: float = 320.0
@export var is_active: bool = true

@onready var animation: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	update_conveyor()

func update_conveyor() -> void:
	if is_active:
		constant_linear_velocity = Vector2(belt_speed, 0)
		animation.play("default")
	else:
		constant_linear_velocity = Vector2.ZERO
		animation.stop()

# Helper function if you want to turn the conveyor on/off during gameplay
func set_conveyor_active(active: bool) -> void:
	is_active = active
	update_conveyor()
