extends Node

var target_position: Vector2 = Vector2.ZERO
var current_target_position: Vector2 = Vector2.ZERO

var should_reposition: bool = false
var should_go_back_to_checkpoint: bool = false

var player_current_health: int = 5
var player_max_health: int = 5

var player_current_silk: int = 0
var player_max_silk: int = 5

var has_needle: bool = false
var player_is_sitting: bool = false
var cocoon_scene_path: String = ""
var cocoon_position: Vector2 = Vector2.ZERO
var cocoon_spawned: bool = false

var player_facing_right: bool = true

enum ItemType { NEEDLE, COGWORK_BATTERY, KEY_TO_LAB_21, HEALTH_UPGRADE, SILK_UPGRADE, FLOWER }
var collected_items: Array[String] = []

var shards_collected: int = 0

var current_scene_path: String = "res://world/main.tscn" 
var scene_path: String = "res://world/main.tscn" 

var intro_dialogue_played: bool = false
var rant_needle_played: bool = false
var is_dialogue_active: bool = false

var broken_objects: Dictionary = {} # Format: {"res://levels/room1.tscn:BreakableObject3": true}
var discovered_locations: Dictionary = {}

var has_talked_to_bella: bool = false
var rubigo_dialogue_step: int = 0

var accepted_wishes: Array = []
var wish_progress: Dictionary = {} # Format: {"wish_id": {"item_name": collected_count, ...}}

var cutscene_frames: Array = []

var wishes_database: Dictionary = {
	"nature_reviver": {
		"name": "Nature Reviver",
		"description": "Rubigo wans me to bring him more flowers. He seems to still have instincts to care for nature despite of his memory loss.",
		"image_path": "res://assets/images/wish/rubigos_wish.png",
		"type": "collect_items",  # Types: collect_items, reach_place, talk_to_npc
		"required_items": {"Flower": 5},
		"npc": "Rubigo"
	}
}

var should_play_lie_animation: bool = false
var should_play_get_up_animation: bool = false

const SAVE_PATH = "user://savegame.save"

func save_game(save_checkpoint: bool = true):
	var checkpoint_x = target_position.x
	var checkpoint_y = target_position.y
	if not save_checkpoint and FileAccess.file_exists(SAVE_PATH):
		var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f:
			var prev = f.get_var()
			f.close()
			checkpoint_x = prev.get("checkpoint_x", target_position.x)
			checkpoint_y = prev.get("checkpoint_y", target_position.y)
	
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		var save_data = {
			"max_health": player_max_health,
			"max_silk": player_max_silk,
			"has_needle": has_needle,
			"collected_items": collected_items,
			"checkpoint_x": checkpoint_x,
			"checkpoint_y": checkpoint_y,
			"saved_scene": scene_path,
			"intro_dialogue_played": intro_dialogue_played,
			"rant_needle_played": rant_needle_played,
			"shards_collected": shards_collected,
			"player_is_sitting": player_is_sitting,
			"cocoon_saved_scene": cocoon_scene_path,
			"cocoon_position_x": cocoon_position.x,
			"cocoon_position_y": cocoon_position.y,
			"cocoon_spawned": cocoon_spawned,
			"broken_objects": broken_objects,
			"discovered_locations": discovered_locations,
			"has_talked_to_bella": has_talked_to_bella,
			"rubigo_dialogue_step": rubigo_dialogue_step,
			"accepted_wishes": accepted_wishes,
			"wish_progress": wish_progress
			}
		
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
		rant_needle_played = save_data.get("rant_needle_played", false)
		shards_collected = save_data.get("shards_collected", 0)
		
		collected_items = Array(save_data.get("collected_items", []), TYPE_STRING, &"", null)
		accepted_wishes = save_data.get("accepted_wishes", [])
		wish_progress = save_data.get("wish_progress", {})
		
		# 2. ENFORCE YOUR RULE: Always reset to max health and zero silk on load (respawn from checkpoint)
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
		
		scene_path = save_data.get("saved_scene", scene_path)
		
		cocoon_scene_path = save_data.get("cocoon_saved_scene", "")
		cocoon_position = Vector2(
			save_data.get("cocoon_position_x", 0.0),
			save_data.get("cocoon_position_y", 0.0)
		)
		cocoon_spawned = save_data.get("cocoon_spawned", false)
		
		broken_objects = save_data.get("broken_objects", {})
		discovered_locations = save_data.get("discovered_locations", {})
		
		has_talked_to_bella = save_data.get("has_talked_to_bella", false)

		rubigo_dialogue_step = save_data.get("rubigo_dialogue_step", 0)

		# 4. Load the level
		var level_to_load = save_data.get("saved_scene", scene_path)
		get_tree().change_scene_to_file(level_to_load)
		
		print("Game loaded! Player restored to full health.")
		return true

# Funkcja do zmieniania sceny z ustawieniem pozycji
func change_scene_to_position(scene_path: String, new_x: float, new_y: float):
	current_target_position = Vector2(new_x, new_y)
	should_reposition = true
	get_tree().change_scene_to_file(scene_path)

func add_accepted_wish(wish_id: String) -> void:
	if not accepted_wishes.has(wish_id):
		accepted_wishes.append(wish_id)
		if wish_id in wishes_database:
			var wish = wishes_database[wish_id]
			if wish.type == "collect_items":
				wish_progress[wish_id] = {}
				for item_name in wish.required_items:
					wish_progress[wish_id][item_name] = 0
		save_game()

func has_accepted_wish(wish_id: String) -> bool:
	return accepted_wishes.has(wish_id)

func get_wish(wish_id: String) -> Dictionary:
	return wishes_database.get(wish_id, {})

func get_all_accepted_wishes() -> Array:
	return accepted_wishes

func update_wish_progress(wish_id: String, item_name: String, amount: int) -> void:
	if wish_id not in wish_progress:
		wish_progress[wish_id] = {}
	wish_progress[wish_id][item_name] = amount
	save_game()

func get_wish_progress(wish_id: String) -> Dictionary:
	return wish_progress.get(wish_id, {})

func is_wish_completed(wish_id: String) -> bool:
	if wish_id not in wishes_database:
		return false
	
	var wish = wishes_database[wish_id]
	
	if wish.type == "collect_items":
		var progress = wish_progress.get(wish_id, {})
		for item_name in wish.required_items:
			if progress.get(item_name, 0) < wish.required_items[item_name]:
				return false
		return true
	
	return false
