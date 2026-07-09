extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	# Set up the interaction wrapper matching your item system
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	# 1. Set this bench's location as the checkpoint respawn point
	# We offset the Y slightly so the player doesn't spawn stuck inside the bench
	Global.target_position = global_position + Vector2(0, -20)
	
	# 2. Tell the game it needs to move the player when this level loads
	Global.should_reposition = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 3. Refill player health and reset silk through setter methods
		if player.has_method("sit_on_bench"):
			player.sit_on_bench()
		# Mark that player is sitting at this checkpoint
		Global.player_is_sitting = true
		if player.has_method("set_current_health"):
			player.set_current_health(Global.player_max_health)
		if player.has_method("set_current_silk"):
			player.set_current_silk(0)
	
	# 4. Also set Global values for systems that might check them (and fallback if player doesn't exist)
	Global.player_current_health = Global.player_max_health
	Global.player_current_silk = 0
	
	# 5. Update the HUD UI immediately so the hearts visual fills up
	var canvas_layer = get_node_or_null("../CanvasLayer")
	if canvas_layer:
		if canvas_layer.has_node("HealthContainer"):
			canvas_layer.get_node("HealthContainer").updateHearts(Global.player_current_health)
		
		# Display your clean visual notification box!
		canvas_layer.show_notification("Progress Saved.")
	
	# 6. Write the progress data to the hard drive
	Global.save_game()
	
	print("Benched! Health refilled and progress saved.")
