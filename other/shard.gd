extends RigidBody2D

@export var health_value: int = 1 # How much health/currency this gives

func _ready() -> void:
	# Give the shard a random spin when it pops out
	angular_velocity = randf_range(-10.0, 10.0)
	
	# Connect the collection area signal
	$CollectionArea.body_entered.connect(_on_player_collected)

func _on_player_collected(body: Node2D) -> void:
	var canvas_layer = get_node_or_null("../CanvasLayer")
	if body.is_in_group("player"):
		# Add to player health/silk or custom currency tracker here!
		# Example:
		Global.shards_collected += 1
		
		if canvas_layer:
			canvas_layer.show_notification("Shards: " + str(Global.shards_collected))
				
		Global.save_game()
		print("Shard collected!")
		queue_free() # Destroy shard from world
