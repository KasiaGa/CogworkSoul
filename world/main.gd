extends Node2D
@onready var dialogue = $Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D

var introShown = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.current_scene_path = scene_file_path
	health_container.setMaxHearts(character_body_2d.maxHealth)
	silk_container.setMaxSilk(character_body_2d.maxSilk)
	health_container.updateHearts(character_body_2d.currentHealth)
	silk_container.updateSilk(character_body_2d.currentSilk)
	
	if not Global.intro_dialogue_played:
		dialogue.start()
		Global.intro_dialogue_played = true # Mark it done so it never auto-triggers agai

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("ui_accept")) and introShown == false:
		#dialogue.start()
		#introShown = true
		pass
