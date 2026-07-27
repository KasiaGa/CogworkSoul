extends Area2D

@export var damage_amount: int = 1
@export var sprite_visible: bool = true
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	# Ensure the sprite is visible and set to the default frame
	if sprite_visible:
		sprite.visible = true
	else:
		sprite.visible = false

func _physics_process(delta: float) -> void:
	# Loop through any physical bodies currently standing inside the spikes
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage") and !body.is_invincible:
			body.take_damage(damage_amount)
