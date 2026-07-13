extends Area2D

@onready var sprite: Sprite2D = $Sprite2D

@export var max_health: int = 3
var current_health: int = max_health

# Exported variable so you can assign the door directly in the Inspector
@export var door_to_block: StaticBody2D 

var is_wiggling: bool = false

func _ready() -> void:
	# 1. Generate a unique key based on the current scene and this node's name
	var unique_id = get_unique_id()
	
	# 2. If this object is already in the Global broken list, instantly delete it
	if Global.broken_objects.get(unique_id, false):
		# If it blocks a door, make sure the door stays open!
		if door_to_block and door_to_block.has_node("InteractionArea2"):
			door_to_block.get_node("InteractionArea2").monitoring = true
		queue_free()
		return

	if door_to_block and door_to_block.has_node("InteractionArea2"):
		door_to_block.get_node("InteractionArea2").monitoring = false

func take_damage(amount: int):
	if current_health <= 0:
		return
		
	current_health -= amount
	
	if current_health > 0:
		wiggle_effect()
	else:
		break_object()

func wiggle_effect():
	if is_wiggling:
		return # Prevent tween overlapping if hit rapidly
	is_wiggling = true
	
	var tween = create_tween()
	var original_pos = sprite.position
	
	# Quick shake left and right
	tween.tween_property(sprite, "position", original_pos + Vector2(-5, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos + Vector2(5, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos + Vector2(-3, 0), 0.05)
	tween.tween_property(sprite, "position", original_pos, 0.05)
	
	# Quick flash white (borrowing from your enemy logic!)
	tween.parallel().tween_property(sprite, "modulate", Color(100.006, 100.006, 100.006, 0.576), 0.05)
	tween.chain().tween_property(sprite, "modulate", Color(1, 1, 1), 0.05)
	
	await tween.finished
	is_wiggling = false

func break_object():
	# Mark this specific object as broken in Global storage
	var unique_id = get_unique_id()
	Global.broken_objects[unique_id] = true
	
	# (Optional) If you want the game to save immediately upon breaking:
	# Global.save_game()

	if door_to_block and door_to_block.has_node("InteractionArea2"):
		door_to_block.get_node("InteractionArea2").monitoring = true
		
	# 2. (Optional) Play a breaking sound or spawn particles here!
	
	# 3. Destroy this object
	queue_free()

func get_unique_id() -> String:
	var current_scene = get_tree().current_scene
	if current_scene:
		return current_scene.scene_file_path + ":" + String(get_path())
	return String(get_path())