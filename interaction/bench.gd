extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea

func _ready() -> void:
	# Set up the interaction wrapper matching your item system
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact():
	# 1. Refill player health completely
	Global.player_current_health = Global.player_max_health
	Global.player_current_silk = 0 # Enforce the 0 silk rule
	
	# 2. Set this bench's location as the checkpoint respawn point
	# We offset the Y slightly so the player doesn't spawn stuck inside the bench
	Global.target_position = global_position + Vector2(0, -20)
	
	# 3. Tell the game it needs to move the player when this level loads
	Global.should_reposition = true
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# Ensure the player's runtime state matches the Global state we just changed
		# (Global.player_current_health was set above, but the player node keeps its own
		# currentHealth variable; update it so future damage calculations use the
		# refreshed value instead of reverting to the old value on the next hit.)
		if player.has_method("sit_on_bench"):
			player.sit_on_bench()
		# Update the player's local health/silk variables to match Global immediately
		if player.has_method("set_current_health"):
			# Prefer using a setter method if the player exposes one
			player.set_current_health(Global.player_current_health)
		else:
			# Fallback: directly assign the variables if present
			if "currentHealth" in player:
				player.currentHealth = Global.player_current_health
			if "currentSilk" in player:
				player.currentSilk = Global.player_current_silk
	
	# 4. Update the HUD UI immediately so the hearts visual fills up
	var canvas_layer = get_node_or_null("../CanvasLayer")
	if canvas_layer:
		if canvas_layer.has_node("HealthContainer"):
			canvas_layer.get_node("HealthContainer").updateHearts(Global.player_current_health)
		
		# Display your clean visual notification box!
		canvas_layer.show_notification("Progress Saved.")
	
	# 5. Write the progress data to the hard drive
	Global.save_game()
	
	print("Benched! Health refilled and progress saved.")
