extends CharacterBody2D

@export var dialogue_start_node: String = "start"

@onready var interaction_area: InteractionArea = $InteractionArea
@onready var dialogue: CanvasLayer = get_tree().current_scene.get_node_or_null("CanvasLayer/Dialogue") as CanvasLayer

const DIALOGUE_FILE = preload("res://dialogue/ami.dialogue")

var _pending_journal_reward: bool = false
var _dialogue_in_progress: bool = false

func _ready() -> void:
	interaction_area.action_name = "Speak"
	interaction_area.interact = Callable(self, "start_dialogue")

func start_dialogue() -> void:
	if _dialogue_in_progress or not is_instance_valid(dialogue) or not dialogue.has_method("start"):
		return

	var already_has_journal: bool = Global.collected_items.has(Global.JOURNAL_ITEM_ID)
	var target_title: String = "already_has_journal" if already_has_journal else dialogue_start_node
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	var ended_callback := Callable(self, "_on_dialogue_ended")
	if not dialogue_manager.is_connected("dialogue_ended", ended_callback):
		dialogue_manager.dialogue_ended.connect(ended_callback)
	_dialogue_in_progress = true
	_pending_journal_reward = not already_has_journal

	dialogue.start(DIALOGUE_FILE, target_title)

func _on_dialogue_ended(_resource) -> void:
	var dialogue_manager = Engine.get_singleton("DialogueManager")
	var ended_callback := Callable(self, "_on_dialogue_ended")
	if dialogue_manager.is_connected("dialogue_ended", ended_callback):
		dialogue_manager.dialogue_ended.disconnect(ended_callback)
	_dialogue_in_progress = false

	if not _pending_journal_reward:
		return
	_pending_journal_reward = false

	if Global.collected_items.has(Global.JOURNAL_ITEM_ID):
		return
	Global.collected_items.append(Global.JOURNAL_ITEM_ID)
	Global.save_game()

	var canvas_layer := get_tree().current_scene.get_node_or_null("CanvasLayer")
	if canvas_layer and canvas_layer.has_method("show_notification"):
		canvas_layer.show_notification("Acquired: Journal")