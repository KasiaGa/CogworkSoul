extends Node

# Przechowuje pozycję docelową (X, Y)
var target_position: Vector2 = Vector2.ZERO

# Zmienna informująca, czy gracz ma zmienić pozycję
var should_reposition: bool = false

var player_current_health: int = 5
var player_max_health: int = 5

var player_current_silk: int = 0
var player_max_silk: int = 5

var has_needle: bool = false
var player_is_sitting: bool = false

enum ItemType { NEEDLE, COGWORK_BATTERY, KEY_TO_LAB_21, HEALTH_UPGRADE, SILK_UPGRADE }
var collected_items: Array[String] = []

var shards_collected: int = 0

var current_scene_path: String = "res://world/main.tscn" 

var intro_dialogue_played: bool = false
var is_dialogue_active: bool = false

# Path to the actual file on the computer
const SAVE_PATH = "user://savegame.save"

func save_game():
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		# Gather everything we want to remember into a tidy package
		var save_data = {
			"max_health": player_max_health,
			"max_silk": player_max_silk,
			"has_needle": has_needle,
			"collected_items": collected_items,
			"checkpoint_x": target_position.x,
			"checkpoint_y": target_position.y,
			"saved_scene": current_scene_path,
			"intro_dialogue_played": intro_dialogue_played,
			"shards_collected": shards_collected,
			"player_is_sitting": player_is_sitting
		}
		
		# Write it to the file
		file.store_var(save_data)
		file.close()
		print("Game successfully saved to: ", OS.get_user_data_dir())


# --- LOAD FUNCTION ---
func load_game():
	if not FileAccess.file_exists(SAVE_PATH):
		print("No save file found.")
		return false
		
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file:
		var save_data = file.get_var()
		file.close()
		
		# 1. Load persistent upgrades and states (using existing variables as defaults!)
		player_max_health = save_data.get("max_health", player_max_health)
		player_max_silk = save_data.get("max_silk", player_max_silk)
		has_needle = save_data.get("has_needle", false)
		intro_dialogue_played = save_data.get("intro_dialogue_played", true)
		shards_collected = save_data.get("shards_collected", 0)
		
		collected_items = Array(save_data.get("collected_items", []), TYPE_STRING, &"", null)
		
		# 2. ENFORCE YOUR RULE: Reset current stats to max health and zero silk on load
		player_current_health = player_max_health
		player_current_silk = 0
		# Restore sitting state if it was saved
		player_is_sitting = save_data.get("player_is_sitting", false)
		
		# 3. Handle positioning
		target_position = Vector2(
			save_data.get("checkpoint_x", 0.0),
			save_data.get("checkpoint_y", 0.0)
		)
		should_reposition = true
		
		# 4. Load the level
		var level_to_load = save_data.get("saved_scene", current_scene_path)
		get_tree().change_scene_to_file(level_to_load)
		
		print("Game loaded! Player restored to full health.")
		return true

# Funkcja do zmieniania sceny z ustawieniem pozycji
func change_scene_to_position(scene_path: String, new_x: float, new_y: float):
	target_position = Vector2(new_x, new_y)
	should_reposition = true
	get_tree().change_scene_to_file(scene_path)
