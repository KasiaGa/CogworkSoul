extends CharacterBody2D

@export var dialogue_start_node: String = "start"

@onready var interaction_area: Area2D = $InteractionArea
@onready var dialogue: CanvasLayer = $"../CanvasLayer/Dialogue"
@onready var rubigo: AnimatedSprite2D = $AnimatedSprite2D

const DIALOGUE_FILE = preload("res://dialogue/rubigo.dialogue")
const WISH_POPUP_SCENE = preload("res://interaction/wish_popup.tscn")

var should_trigger_popup: bool = false

func _ready() -> void:
	rubigo.play("default")
	interaction_area.action_name = "Speak"
	interaction_area.interact = Callable(self, "start_dialogue")

func start_dialogue() -> void:
	if not dialogue:
		return

	var target_title: String = "start"
	
	# Select line based on Global step
	match Global.rubigo_dialogue_step:
		0:
			target_title = "start"
		1:
			target_title = "dialogue2"
		_:
			target_title = "dialogue3"

	if dialogue and dialogue.has_method("start"):
		var dm = Engine.get_singleton("DialogueManager")
		
		var line_cb = Callable(self, "_on_dialogue_line_shown")
		var ended_cb = Callable(self, "_on_dialogue_ended")
		
		if not dm.is_connected("got_dialogue", line_cb):
			dm.got_dialogue.connect(line_cb)
		if not dm.is_connected("dialogue_ended", ended_cb):
			dm.dialogue_ended.connect(ended_cb)

		dialogue.start(DIALOGUE_FILE, target_title)

func _on_dialogue_line_shown(line) -> void:
	# Detect when Rubigo asks for flowers in dialogue2
	if line.character == "Rubigo" and line.text == "I need more. Can you bring me more?":
		should_trigger_popup = true

func _on_dialogue_ended(_resource) -> void:
	# Clean up listeners
	var dm = Engine.get_singleton("DialogueManager")
	var line_cb = Callable(self, "_on_dialogue_line_shown")
	var ended_cb = Callable(self, "_on_dialogue_ended")
	
	if dm.is_connected("got_dialogue", line_cb):
		dm.got_dialogue.disconnect(line_cb)
	if dm.is_connected("dialogue_ended", ended_cb):
		dm.dialogue_ended.disconnect(ended_cb)

	# Handle step advancement depending on which dialogue just finished
	if should_trigger_popup:
		should_trigger_popup = false
		_show_nature_reviver_popup()
	else:
		# If it was step 0 (~start) finishing, advance to step 1 so next time is ~dialogue2
		if Global.rubigo_dialogue_step == 0:
			Global.rubigo_dialogue_step = 1
			Global.save_game()

func _show_nature_reviver_popup() -> void:
	# 1. Create a new CanvasLayer in code
	var canvas = CanvasLayer.new()
	canvas.layer = 100 # Put it on top of everything else
	
	# 2. Spawn the popup
	var popup = WISH_POPUP_SCENE.instantiate()
	
	# 3. Put the popup inside the CanvasLayer
	canvas.add_child(popup)
	
	# 4. Add the CanvasLayer (and popup) to the active game window
	get_tree().root.add_child(canvas)
	
	# 5. Configure your popup as usual
	popup.setup("nature_reviver", "Nature Reviver", "Accept wish?")
	popup.response_selected.connect(_on_wish_response)
	
	# 6. Automatically delete the CanvasLayer when the popup closes
	popup.tree_exited.connect(func(): canvas.queue_free())
	
func _on_wish_response(accepted: bool, wish_id: String) -> void:
	if accepted:
		Global.add_accepted_wish(wish_id)
		# Example: Update wish progress when items are collected
		Global.update_wish_progress(wish_id, "Flower", 5)
		
	# Advance to step 2 so Rubigo now permanently says ~dialogue3
	Global.rubigo_dialogue_step = 2
	Global.save_game()
