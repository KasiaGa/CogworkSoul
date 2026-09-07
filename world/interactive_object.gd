extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea

const INFO_PROMPT_SCENE = preload("res://interaction/info_prompt.tscn")

@export var prompt_title: String = "Object"
@export var prompt_text: String = "Inspect this object"

func _ready() -> void:
	interaction_area.action_name = "Inspect"
	
	# Assign the interaction callback
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact() -> void:
	_show_prompt()

func _show_prompt() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	
	var prompt = INFO_PROMPT_SCENE.instantiate()
	canvas.add_child(prompt)
	get_tree().root.add_child(canvas)
	
	# Pass Title and Text for display
	prompt.setup(prompt_title, prompt_text)
	
	prompt.tree_exited.connect(func(): canvas.queue_free())
