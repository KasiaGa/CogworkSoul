extends Area2D # Changed from Node2D/StaticBody2D

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
var cocoon_health: int = 3  

func _ready() -> void:
	add_to_group("cocoon")
	if animated_sprite and animated_sprite.sprite_frames:
		animated_sprite.play("default")

func take_cocoon_damage(amount: int) -> void:
	cocoon_health -= amount
	
	# Flash white effect
	if animated_sprite:
		var tween = create_tween()
		tween.tween_property(animated_sprite, "modulate", Color(1.5, 1.5, 1.5), 0.1)
		tween.tween_property(animated_sprite, "modulate", Color(1, 1, 1), 0.1)
	
	if cocoon_health <= 0:
		break_cocoon()

func break_cocoon() -> void:
	if animated_sprite and animated_sprite.sprite_frames.has_animation("break"):
		animated_sprite.play("break")
		await get_tree().create_timer(0.3).timeout
	
	# Reward player
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		var player = players[0]
		if player.has_method("break_cocoon"):
			player.break_cocoon()
			
	queue_free()
