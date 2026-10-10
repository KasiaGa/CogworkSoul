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

var location_metadata: Dictionary = {
	"res://world/main.tscn": {
		"name": "Cogwork Nest",
		"image": "res://assets/images/locations/cogwork_factory.png"
	},
	"res://world/CogworkCore.tscn": {
		"name": "Cogwork Factory",
		"image": "res://assets/images/locations/factory_2.png"
	},
	"res://world/cogwork_factory_2.tscn": {
		"name": "Cogwork Factory",
		"image": "res://assets/images/locations/factory_2.png"
	},
	"res://world/cogwork_factory_3.tscn": {
		"name": "Cogwork Factory",
		"image": "res://assets/images/locations/factory_3.png"
	},
	"res://world/bellas_cave.tscn": {
		"name": "Bella's Cave",
		"image": "res://assets/images/locations/bellas_cave.png"
	}
}

func get_location_name(scene_path: String) -> String:
	if scene_path in location_metadata:
		return location_metadata[scene_path]["name"]
	return scene_path

func get_location_image(scene_path: String) -> String:
	if scene_path in location_metadata:
		return location_metadata[scene_path]["image"]
	return ""

var should_play_lie_animation: bool = false
var should_play_get_up_animation: bool = false

var total_playtime: float = 0.0  # in seconds

const SAVE_PATH_FORMAT = "user://save_slot_%d.save"
const SLOT_COUNT = 5
var current_slot: int = 1
var last_bench_texture_path: String = ""

func get_save_path_for_slot(slot:int) -> String:
	return SAVE_PATH_FORMAT % slot

func save_game(save_checkpoint: bool = true, slot: int = -1):
	var slot_to_use = slot if slot != -1 else current_slot
	var checkpoint_x = target_position.x
	var checkpoint_y = target_position.y
	if not save_checkpoint and FileAccess.file_exists(get_save_path_for_slot(slot_to_use)):
		var f = FileAccess.open(get_save_path_for_slot(slot_to_use), FileAccess.READ)
		if f:
			var prev = f.get_var()
			f.close()
			checkpoint_x = prev.get("checkpoint_x", target_position.x)
			checkpoint_y = prev.get("checkpoint_y", target_position.y)
	
	var file = FileAccess.open(get_save_path_for_slot(slot_to_use), FileAccess.WRITE)
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
		"wish_progress": wish_progress,
		"thumbnail": last_bench_texture_path,
		"saved_at": Time.get_unix_time_from_system(),
		"playtime": total_playtime
		}
		
		file.store_var(save_data)
		file.close()
		print("Game successfully saved to: ", get_save_path_for_slot(slot_to_use))


# --- LOAD FUNCTION ---
func load_game(slot:int = -1):
	var slot_to_use = slot if slot != -1 else current_slot
	if not FileAccess.file_exists(get_save_path_for_slot(slot_to_use)):
		print("No save file found for slot ", slot_to_use)
		return false
		
	var file = FileAccess.open(get_save_path_for_slot(slot_to_use), FileAccess.READ)
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
		
		# Load playtime
		total_playtime = save_data.get("playtime", 0.0)
		
		# 2. ENFORCE YOUR RULE: Always reset to max health and zero silk on load (respawn from checkpoint)
		player_current_health = player_max_health
		player_current_silk = 0
		# Restore sitting state if it was saved
		player_is_sitting = save_data.get("player_is_sitting", false)
		
		# 3. Handle positioning
		target_position = Vector2(save_data.get("checkpoint_x", 0.0), save_data.get("checkpoint_y", 0.0))
		current_target_position = Vector2.ZERO
		should_reposition = true
	
		print("Loaded position: ", target_position)
		print("current_target_position reset to: ", current_target_position)
		
		scene_path = save_data.get("saved_scene", scene_path)
		
		cocoon_scene_path = save_data.get("cocoon_saved_scene", "")
		cocoon_position = Vector2(save_data.get("cocoon_position_x", 0.0), save_data.get("cocoon_position_y", 0.0))
		cocoon_spawned = save_data.get("cocoon_spawned", false)
		
		broken_objects = save_data.get("broken_objects", {})
		discovered_locations = save_data.get("discovered_locations", {})
		
		has_talked_to_bella = save_data.get("has_talked_to_bella", false)
	
		rubigo_dialogue_step = save_data.get("rubigo_dialogue_step", 0)
	
		# 4. Load the level
		var level_to_load = save_data.get("saved_scene", scene_path)
		get_tree().change_scene_to_file(level_to_load)
		
		print("Game loaded from slot ", slot_to_use, "! Player restored to full health.")
		return true

# Funkcja do zmieniania sceny z ustawieniem pozycji
func change_scene_to_position(scene_path: String, new_x: float, new_y: float):
	current_target_position = Vector2(new_x, new_y)
	should_reposition = true
	get_tree().change_scene_to_file(scene_path)

func get_save_slots() -> Array:
	var slots = []
	for i in range(1, SLOT_COUNT + 1):
		var path = get_save_path_for_slot(i)
		var exists = FileAccess.file_exists(path)
		var meta = {}
		if exists:
			var f = FileAccess.open(path, FileAccess.READ)
			if f:
				var d = f.get_var()
				f.close()
				meta = {"slot": i, "exists": true, "scene": d.get("saved_scene", ""), "checkpoint_x": d.get("checkpoint_x", 0), "checkpoint_y": d.get("checkpoint_y", 0), "thumbnail": d.get("thumbnail", ""), "saved_at": d.get("saved_at", 0), "playtime": d.get("playtime", 0.0)}
		else:
			meta = {"slot": i, "exists": false}
		slots.append(meta)
	return slots

func set_current_slot(slot:int) -> void:
	if slot >= 1 and slot <= SLOT_COUNT:
		current_slot = slot

func delete_save(slot:int) -> void:
	var path = get_save_path_for_slot(slot)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)
		print("Save slot ", slot, " deleted.")
	else:
		print("No save file found for slot ", slot)

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
