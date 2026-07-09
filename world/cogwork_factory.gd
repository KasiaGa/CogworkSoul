extends Node2D
@onready var dialogue = $Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.current_scene_path = scene_file_path
	health_container.setMaxHearts(character_body_2d.maxHealth)
	silk_container.setMaxSilk(character_body_2d.maxSilk)
	health_container.updateHearts(character_body_2d.currentHealth)
	silk_container.updateSilk(character_body_2d.currentSilk)
	
	if Global.cocoon_spawned and Global.cocoon_scene_path == get_tree().current_scene.scene_file_path:
		spawn_persistant_cocoon()
	
	# when i sit on bench:
	#Global.player_current_health = Global.player_max_health

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
		pass

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
