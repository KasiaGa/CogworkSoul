extends Control

const STARTING_LEVEL_PATH = "res://world/main.tscn"
const FRAMES_FOLDER = "res://assets/cutscenes/intro/"
const FRAME_PREFIX = "rant"
const TOTAL_FRAMES = 183
const FPS = 30

@onready var sprite = $AnimatedSprite2D
@onready var loading_label = $LoadingLabel

func _ready() -> void:
	loading_label.visible = true
	
	await get_tree().process_frame
	
	var sprite_frames = SpriteFrames.new()
	sprite_frames.add_animation("intro")
	sprite_frames.set_animation_speed("intro", FPS)
	
	for i in range(TOTAL_FRAMES):
		var frame_name = FRAMES_FOLDER + FRAME_PREFIX + str(i).pad_zeros(4) + ".jpg"
		var texture = load(frame_name)
		if texture:
			sprite_frames.add_frame("intro", texture)
		
		if i % 10 == 0:
			await get_tree().process_frame
	
	sprite.sprite_frames = sprite_frames
	sprite_frames.set_animation_loop("intro", false)
	
	loading_label.visible = false
	
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
