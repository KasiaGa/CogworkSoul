extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var main: Node2D = $"."



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
	Global.change_scene_to_position("res://world/main.tscn", -520.0, 420.0)
