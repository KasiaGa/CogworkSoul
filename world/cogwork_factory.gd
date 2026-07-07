extends Node2D
@onready var dialogue = $Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.current_scene_path = scene_file_path
	health_container.setMaxHearts(character_body_2d.startHealth)
	silk_container.setMaxSilk(character_body_2d.startSilk)
	health_container.updateHearts(character_body_2d.currentHealth)
	
	# when i sit on bench:
	#Global.player_current_health = Global.player_max_health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		pass
