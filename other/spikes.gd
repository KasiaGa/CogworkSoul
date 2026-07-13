extends Area2D

@export var damage_amount: int = 1

func _physics_process(delta: float) -> void:
	# Loop through any physical bodies currently standing inside the spikes
	for body in get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage") and !body.is_invincible:
			body.take_damage(damage_amount)
