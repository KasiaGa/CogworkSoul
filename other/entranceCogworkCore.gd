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
	Global.change_scene_to_position("res://main.tscn", -520.0, 420.0)
