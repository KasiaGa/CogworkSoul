extends Area2D

# Expose variables to the Inspector so you can customize each exit easily!
@export_file("*.tscn") var target_scene: String
@export var spawn_location: Vector2
@export var transition_enabled: bool = true

func _ready() -> void:
	# Connect the body entered signal to detect the player
	body_entered.connect(_on_body_entered)

func set_transition_enabled(enabled: bool) -> void:
	transition_enabled = enabled
	if not transition_enabled:
		return
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			_on_body_entered(body)

func _on_body_entered(body: Node2D) -> void:
	if transition_enabled and body.is_in_group("player"):
		# 1. Stop the player from moving/falling mid-transition
		body.is_transitioning = true
		body.velocity = Vector2.ZERO
		
		# If flip_h is true, they were facing right. If false, facing left.
		Global.player_facing_right = body.get_node("rant").flip_h
		
		# 2. Fade to black *before* we switch scenes
		if body.has_method("create_fade_out"):
			await body.create_fade_out(0.4) # Slightly faster fade feels crisper for doors
			
		# 3. Swap maps! (The incoming player's _ready loop will trigger the fade_in)
		if target_scene != "":
			Global.change_scene_to_position(target_scene, spawn_location.x, spawn_location.y)
		else:
			push_warning("TransitionZone: No target scene specified!")
