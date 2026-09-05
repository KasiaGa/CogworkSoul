extends Node2D

@onready var interaction_area: InteractionArea = $InteractionArea

const PROMPT_SCENE = preload("res://interaction/prompt.tscn") # Point to your prompt.tscn path
const LIFT_ICON = preload("res://assets/images/world/bell6.png") # Path to your icon image

func _ready() -> void:
	# 1. Text shown floating above the lift (e.g. "↑ Inspect")
	interaction_area.action_name = "Inspect"
	
	# 2. Assign the interaction callback
	interaction_area.interact = Callable(self, "_on_interact")

func _on_interact() -> void:
	_show_prompt()

func _show_prompt() -> void:
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	
	var prompt = PROMPT_SCENE.instantiate()
	canvas.add_child(prompt)
	get_tree().root.add_child(canvas)
	
	# Pass Title, Question, and optional Icon
	prompt.setup("An old lift", "Use battery?", LIFT_ICON)
	prompt.response_selected.connect(_on_prompt_response)
	
	prompt.tree_exited.connect(func(): canvas.queue_free())

func _on_prompt_response(confirmed: bool) -> void:
	if confirmed:
		if Global.has_battery: # Example item check
			print("Player used battery! Activating lift...")
			# Play lift movement animation / logic here
		else:
			print("Player confirmed, but lacks required item.")
	else:
		print("Player selected No.")
