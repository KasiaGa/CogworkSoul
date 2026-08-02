extends Node2D
@onready var dialogue = $CanvasLayer/Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D

var introShown = false;

const DIALOGUE_FILE = preload("res://dialogue/intro.dialogue")
const INTRO_STEP_1 = preload("res://dialogue/intro_step_1.dialogue")
const INTRO_STEP_2 = preload("res://dialogue/intro_step_2.dialogue")

# Intro progression tracking
var intro_stage: int = 0  # 0 = not started, 1 = after first steps, 2 = after second steps, 3 = after lie/get_up, 4 = main intro
var intro_steps_moved: int = 0
const STEPS_BEFORE_DIALOGUE_1: int = 3
const STEPS_BEFORE_DIALOGUE_2: int = 3


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.current_scene_path = scene_file_path
	health_container.setMaxHearts(character_body_2d.maxHealth)
	silk_container.setMaxSilk(character_body_2d.maxSilk)
	health_container.updateHearts(character_body_2d.currentHealth)
	silk_container.updateSilk(character_body_2d.currentSilk)
	
	if Global.cocoon_spawned and Global.cocoon_scene_path == get_tree().current_scene.scene_file_path:
		spawn_persistant_cocoon()

	# Don't play intro dialogue automatically - wait for player movement
	if not Global.intro_dialogue_played:
		intro_stage = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	# Track player movement for intro progression
	if intro_stage == 0 and not Global.intro_dialogue_played:
		# Player moved, trigger first dialogue
		if character_body_2d.velocity.x != 0:
			intro_steps_moved += 1
			if intro_steps_moved >= STEPS_BEFORE_DIALOGUE_1:
				intro_stage = 1
				dialogue.start(INTRO_STEP_1, "intro_step_1")
	
	elif intro_stage == 1 and not dialogue.is_visible():
		# First dialogue done, wait for more movement
		if character_body_2d.velocity.x != 0:
			intro_steps_moved += 1
			if intro_steps_moved >= STEPS_BEFORE_DIALOGUE_1 + STEPS_BEFORE_DIALOGUE_2:
				intro_stage = 2
				dialogue.start(INTRO_STEP_2, "intro_step_2")
	
	elif intro_stage == 2 and not dialogue.is_visible():
		# Second dialogue done, trigger lie animation and fade
		if character_body_2d.velocity.x != 0:
			intro_stage = 3
			trigger_lie_sequence()  # This will set intro_stage to 4 when done
			
	# intro_stage == 3 is handled by trigger_lie_sequence which will start the main intro when done
		
func spawn_persistant_cocoon() -> void:
	var cocoon_scene = load("res://other/cocoon.tscn")
	if cocoon_scene:
		var cocoon = cocoon_scene.instantiate()
		
		# Add it directly to the level scene tree
		add_child(cocoon)
		cocoon.global_position = Global.cocoon_position
		
		print("Cocoon spawned at old death location: ", Global.cocoon_position)
	else:
		push_error("Failed to load cocoon scene from Level Manager.")

func trigger_lie_sequence() -> void:
	# Disable player input
	character_body_2d.set_physics_process(false)
	
	# Play lie animation
	character_body_2d.rant.animation = "lie" + ("" if Global.player_facing_right else "_left")
	await get_tree().create_timer(1.0).timeout  # Wait for animation to play
	
	# Fade to black
	var fade_layer = CanvasLayer.new()
	fade_layer.layer = 1000
	add_child(fade_layer)

	var fade_rect = ColorRect.new()
	# Use full-anchor layout so it covers the whole screen
	fade_rect.anchor_left = 0.0
	fade_rect.anchor_top = 0.0
	fade_rect.anchor_right = 1.0
	fade_rect.anchor_bottom = 1.0
	fade_rect.offset_left = 0.0
	fade_rect.offset_top = 0.0
	fade_rect.offset_right = 0.0
	fade_rect.offset_bottom = 0.0
	# Solid black color; we'll fade by modulating alpha
	fade_rect.color = Color(0, 0, 0, 1)
	fade_rect.modulate = Color(1, 1, 1, 0)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade_layer.add_child(fade_rect)

	# Fade in to black (0.5s) by increasing modulate alpha
	var tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 1.0, 0.5)
	await tween.finished

	# Wait 5 seconds while screen is black
	await get_tree().create_timer(5.0).timeout

	# Fade out from black (0.5s)
	tween = create_tween()
	tween.tween_property(fade_rect, "modulate:a", 0.0, 0.5)
	await tween.finished

	fade_layer.queue_free()
	
	# Play get_up animation
	character_body_2d.rant.animation = "get_up" + ("" if Global.player_facing_right else "_left")
	await get_tree().create_timer(1.0).timeout  # Wait for animation to play
	
	# Re-enable player input
	character_body_2d.set_physics_process(true)
	
	# Mark stage as done
	intro_stage = 4

	# Start the main intro dialogue now that lie/get_up sequence finished
	dialogue.start(DIALOGUE_FILE, "start")
	Global.intro_dialogue_played = true
