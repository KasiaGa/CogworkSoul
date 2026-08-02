extends Control

const STARTING_LEVEL_PATH = "res://world/main.tscn"
const FRAMES_FOLDER = "res://assets/cutscenes/intro/"
const FRAME_PREFIX = "rant"
const TOTAL_FRAMES = 183
const FPS = 30

@onready var sprite = $AnimatedSprite2D
@onready var loading_label = $LoadingLabel
@onready var loading_icon = $LoadingIcon

func _ready() -> void:
	loading_label.visible = false
	loading_icon.visible = false
	
	var textures = Global.cutscene_frames
	
	if textures.is_empty():
		push_error("No cutscene frames loaded! Make sure loading_screen preloaded them.")
		return
	
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("intro")
	sprite_frames.set_animation_speed("intro", FPS)
	
	for texture in textures:
		sprite_frames.add_frame("intro", texture)
	
	sprite.sprite_frames = sprite_frames
	sprite_frames.set_animation_loop("intro", false)
	
	sprite.animation_finished.connect(_on_animation_finished)
	
	sprite.play("intro")


func _on_animation_finished() -> void:
	_start_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_ENTER:
			_start_game()
			get_tree().root.set_input_as_handled()


func _start_game() -> void:
	loading_label.visible = true
	loading_icon.visible = true
	loading_icon.play()
	
	set_process_input(false)
	
	await get_tree().process_frame
	
	# RESET GLOBAL DATA FOR A FRESH NEW GAME
	Global.player_max_health = 5
	Global.player_current_health = 5
	Global.player_max_silk = 5
	Global.player_current_silk = 0
	Global.has_needle = false
	Global.player_is_sitting = false
	Global.collected_items.clear()
	Global.intro_dialogue_played = false
	Global.should_reposition = false
	Global.target_position = Vector2.ZERO
	
	get_tree().change_scene_to_file(STARTING_LEVEL_PATH)
