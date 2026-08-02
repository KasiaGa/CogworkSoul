extends Control

const CUTSCENE_PATH = "res://cutscenes/intro_cutscene.tscn"
const FRAMES_FOLDER = "res://assets/cutscenes/intro/"
const FRAME_PREFIX = "rant"
const TOTAL_FRAMES = 183

@onready var loading_label = $LoadingLabel
@onready var loading_icon = $LoadingIcon

func _ready() -> void:
	loading_label.visible = true
	loading_icon.visible = true
	loading_icon.play()
	
	await get_tree().process_frame
	
	var textures = []
	for i in range(TOTAL_FRAMES):
		var frame_name = FRAMES_FOLDER + FRAME_PREFIX + str(i).pad_zeros(4) + ".jpg"
		var texture = load(frame_name)
		if texture:
			textures.append(texture)
		
		if i % 2 == 0:
			await get_tree().process_frame
	
	Global.cutscene_frames = textures
	
	get_tree().change_scene_to_file(CUTSCENE_PATH)
