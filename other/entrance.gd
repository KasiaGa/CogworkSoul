extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea2

# Select your target scene file directly in the Godot Inspector
@export_file("*.tscn") var target_scene_path: String = "res://world/CogworkCore.tscn"

# Export spawn position coordinates
@export var spawn_x: float = 620.0
@export var spawn_y: float = 420.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interact():
	var player = get_tree().get_first_node_in_group("player") 
	if player and player.has_method("play_entrance_animation"):
		await player.play_entrance_animation()
		
	# Safety check to prevent errors if no scene is selected in Inspector
	if target_scene_path.is_empty():
		push_warning("Target scene path is not set on " + name)
		return

	Global.change_scene_to_position(target_scene_path, spawn_x, spawn_y)
