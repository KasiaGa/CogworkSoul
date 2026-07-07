extends Node2D
@onready var dialogue = $Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D

var introShown = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	health_container.setMaxHearts(character_body_2d.startHealth)
	silk_container.setMaxSilk(character_body_2d.startSilk)
	health_container.updateHearts(character_body_2d.currentHealth)

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	#if (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("left") or Input.is_action_just_pressed("right") or Input.is_action_just_pressed("ui_accept")) and introShown == false:
		#dialogue.start()
		#introShown = true
		pass
