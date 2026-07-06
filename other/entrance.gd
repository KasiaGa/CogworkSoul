extends StaticBody2D

@onready var interaction_area: InteractionArea = $InteractionArea2


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	interaction_area.interact = Callable(self, "_on_interact")


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _on_interact():
	Global.change_scene_to_position("res://CogworkCore.tscn", 620, 420)
