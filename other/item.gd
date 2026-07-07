extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea

@export var item_id: String
@export var item_type: Global.ItemType = Global.ItemType.NEEDLE

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# 1. Check if this specific item has already been picked up in the past
	if Global.collected_items.has(item_id):
		queue_free() # Delete it instantly before the player even sees it
		return       # Exit early so we don't bind the interaction
		
	interaction_area.interact = Callable(self, "_on_interact")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_interact():
	# 2. Add this item's ID to our global "don't respawn" list
	Global.collected_items.append(item_id)
	
	# 3. Give the player their reward depending on what type of item this is
	match item_type:
		Global.ItemType.NEEDLE:
			print("Picked up the needle!")
			Global.has_needle = true 
		Global.ItemType.KEY_TO_LAB_21:
			print("Picked up a key!")
		Global.ItemType.HEALTH_UPGRADE:
			print("Max health increased!")
			Global.player_max_health += 1
			Global.player_current_health = Global.player_max_health
		Global.ItemType.SILK_UPGRADE:
			print("Max silk increased!")
			Global.player_max_silk += 1
			Global.player_current_silk = Global.player_max_silk
			
	# 4. Make the item disappear
	queue_free()
