extends CharacterBody2D

# Drag your dialogue .dialogue file into this slot in the Inspector
#@export var dialogue_resource: DialogueResource
@export var dialogue_start_node: String = "start"

@onready var interaction_area: Area2D = $InteractionArea
@onready var dialogue: CanvasLayer = $"../CanvasLayer/Dialogue"

const DIALOGUE_FILE = preload("res://dialogue/bella.dialogue")

var player_in_range: bool = false

func _ready() -> void:
	# 1. This is what the label will show (e.g. "[E] to Speak")
	interaction_area.action_name = "Speak"
	
	# 2. Point the InteractionArea's custom trigger to our dialogue system
	interaction_area.interact = Callable(self, "start_dialogue")

#func _unhandled_input(event: InputEvent) -> void:
#	# "ui_accept" is Enter/Space by default, or use your custom "interact" action
#	if player_in_range and event.is_action_pressed("ui_accept"):
#		start_dialogue()

func start_dialogue() -> void:
	if not dialogue: return

	var target_title: String = dialogue_start_node
	if Global.has_talked_to_bella:
		target_title = "dialogue2"

	if dialogue and dialogue.has_method("start"):
		dialogue.start(DIALOGUE_FILE, target_title)
	# Save the progress globally
	Global.has_talked_to_bella = true
	Global.save_game()

#func _on_player_entered(body: Node2D) -> void:
#	# Adjust "Player" to match whatever your Player script or Group is called
#	if body.is_in_group("Player") or body.name == "Player":
#		player_in_range = true
#		# Optional: Show an "Interact [E]" prompt UI here
#
#func _on_player_exited(body: Node2D) -> void:
#	if body.is_in_group("Player") or body.name == "Player":
#		player_in_range = false
#		# Optional: Hide the "Interact [E]" prompt UI here
