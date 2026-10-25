extends Node

const DEBUG_STATE_PANEL_SCRIPT = preload("res://other/debug_state_panel.gd")
const LOCATION_BANNER = preload("res://gui/location_banner.tscn")
const REGION_RETURN_BANNER = preload("res://gui/region_return_banner.tscn")

var debug_state_panel: Node
var debug_was_paused: bool = false

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
var cocoon_shards: int = 0

var player_facing_right: bool = true

enum ItemType { NEEDLE, COGWORK_BATTERY, KEY_TO_LAB_21, HEALTH_UPGRADE, SILK_UPGRADE, FLOWER, MODULE, JOURNAL }
var collected_items: Array[String] = []
const JOURNAL_ITEM_ID: String = "journal"
const ENEMY_JOURNAL_DATA: Dictionary = {
	"cogbug": {
		"name": "Cogbug",
		"description": "A stubborn clockwork crawler that patrols the factory floor.",
		"image_path": "res://assets/images/enemy/cogbug.png"
	},
	"flying_cogbug": {
		"name": "Flying Cogbug",
		"description": "A winged cogbug that drifts through open spaces and pursues intruders.",
		"image_path": "res://assets/images/enemy/flying_cogbug.png"
	},
	"factory_stalker": {
		"name": "Factory Stalker",
		"description": "A relentless hunter that accelerates toward anything it sees moving.",
		"image_path": "res://assets/images/enemy/enemy2223.png"
	},
	"tangled_guardian": {
		"name": "Tangled Guardian",
		"description": "A massive guardian that lashes out with long, tangled cables to protect the factory.",
		"image_path": "res://assets/images/npc/tangled_guardian_resized.png"
	}
}

const MODULE_SLOT_COUNT: int = 3
var collected_modules: Array[String] = []
var equipped_modules: Array[String] = ["", "", ""]
var module_database: Dictionary = {
	"shard_collector": {
		"name": "Shard Collector",
		"description": "Enemies drop twice as many shards while this module is equipped.",
		"image_path": "res://assets/images/module/module3_2.png",
		"shard_drop_multiplier": 2.0
	},
	"resonance_coil": {
		"name": "Resonance Coil",
		"description": "Every third hit against the same enemy deals double damage.",
		"image_path": "res://assets/images/item/item.png",
		"bonus_damage_every": 3,
		"bonus_damage_multiplier": 2.0
	},
	"brass_slash": {
		"name": "Brass Slash",
		"description": "Extends the needle's reach by 25% and leaves a brass-gold slash trail.",
		"image_path": "res://assets/images/item/item.png",
		"attack_reach_multiplier": 1.25
	}
}

func get_module_data(module_id: String) -> Dictionary:
	var display_name = module_id.replace("_", " ").capitalize()
	return module_database.get(module_id, {
		"name": display_name,
		"description": "An unusual module. Its properties are not yet understood.",
		"image_path": "res://assets/images/item/item.png"
	})

func collect_module(module_id: String) -> bool:
	if module_id.is_empty() or collected_modules.has(module_id):
		return false
	collected_modules.append(module_id)
	return true

func equip_module(module_id: String, slot_index: int) -> bool:
	if not collected_modules.has(module_id) or slot_index < 0 or slot_index >= MODULE_SLOT_COUNT:
		return false
	for index in range(equipped_modules.size()):
		if equipped_modules[index] == module_id:
			if index == slot_index:
				return true
			equipped_modules[index] = ""
	equipped_modules[slot_index] = module_id
	return true

func unequip_module(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < equipped_modules.size():
		equipped_modules[slot_index] = ""

func is_module_equipped(module_id: String) -> bool:
	return equipped_modules.has(module_id)

func get_enemy_shard_drop_count(minimum: int, maximum: int) -> int:
	var drop_count = randi_range(minimum, maximum)
	for module_id in equipped_modules:
		var module_data: Dictionary = module_database.get(module_id, {})
		var multiplier: float = module_data.get("shard_drop_multiplier", 1.0)
		drop_count = int(round(drop_count * multiplier))
	return drop_count

func get_enemy_hit_damage(hit_number: int, base_damage: int) -> int:
	var damage = base_damage
	for module_id in equipped_modules:
		var module_data: Dictionary = module_database.get(module_id, {})
		var hit_interval: int = int(module_data.get("bonus_damage_every", 0))
		if hit_interval > 0 and hit_number % hit_interval == 0:
			var multiplier: float = module_data.get("bonus_damage_multiplier", 1.0)
			damage = int(round(damage * multiplier))
	return damage

func reset_modules() -> void:
	collected_modules.clear()
	equipped_modules.clear()
	for _slot_index in range(MODULE_SLOT_COUNT):
		equipped_modules.append("")

var shards_collected: int = 0

var current_scene_path: String = "res://world/main.tscn" 
var scene_path: String = "res://world/main.tscn" 
var current_region_id: String = ""
var transition_origin_region_id: String = ""
var region_transition_pending: bool = false

var intro_dialogue_played: bool = false
var rant_needle_played: bool = false
var is_dialogue_active: bool = false

var broken_objects: Dictionary = {} # Format: {"res://levels/room1.tscn:BreakableObject3": true}
var discovered_locations: Dictionary = {}
var visited_rooms: Dictionary = {}
var defeated_bosses: Dictionary = {}
var defeated_enemies: Dictionary = {}

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

var location_names: Dictionary = {
	"res://world/main.tscn": "Cogwork Nest",
	"res://world/CogworkCore.tscn": "Cogwork Factory",
	"res://world/cogwork_factory_2.tscn": "Cogwork Factory",
	"res://world/cogwork_factory_3.tscn": "Cogwork Factory",
	"res://world/bellas_cave.tscn": "Bella's Cave"
}

func get_location_name(scene_path: String) -> String:
	return location_names.get(scene_path, scene_path)

var should_play_lie_animation: bool = false
var should_play_get_up_animation: bool = false

var total_playtime: float = 0.0  # in seconds

const SAVE_PATH_FORMAT = "user://save_slot_%d.save"
const SLOT_COUNT = 5
# Preview shown when the save has not recorded a bench checkpoint yet.
const NO_BENCH_PREVIEW_IMAGE_PATH: String = "res://assets/images/world/device1.png"
var current_slot: int = 1
var last_bench_preview_path: String = ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and (event.keycode == KEY_P or event.physical_keycode == KEY_P):
		_toggle_debug_state_panel()
		get_viewport().set_input_as_handled()

func _toggle_debug_state_panel() -> void:
	if debug_state_panel == null:
		debug_state_panel = DEBUG_STATE_PANEL_SCRIPT.new()
		add_child(debug_state_panel)
	if bool(debug_state_panel.call("is_open")):
		close_debug_state_panel()
	else:
		debug_was_paused = get_tree().paused
		get_tree().paused = true
		debug_state_panel.call("open_panel")

func close_debug_state_panel() -> void:
	if debug_state_panel == null or not bool(debug_state_panel.call("is_open")):
		return
	debug_state_panel.call("close_panel")
	get_tree().paused = debug_was_paused

func get_save_path_for_slot(slot:int) -> String:
	return SAVE_PATH_FORMAT % slot

func save_game(save_checkpoint: bool = true, slot: int = -1) -> bool:
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
		var save_data := _build_save_data(checkpoint_x, checkpoint_y)
		file.store_var(save_data)
		file.close()
		print("Game successfully saved to: ", get_save_path_for_slot(slot_to_use))
		return true
	return false

func _build_save_data(checkpoint_x: float, checkpoint_y: float) -> Dictionary:
	return {
		"max_health": player_max_health,
		"max_silk": player_max_silk,
		"has_needle": has_needle,
		"collected_items": collected_items,
		"collected_modules": collected_modules,
		"equipped_modules": equipped_modules,
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
		"cocoon_shards": cocoon_shards,
		"broken_objects": broken_objects,
		"defeated_bosses": defeated_bosses,
		"defeated_enemies": defeated_enemies,
		"discovered_locations": discovered_locations,
		"visited_rooms": visited_rooms,
		"has_talked_to_bella": has_talked_to_bella,
		"rubigo_dialogue_step": rubigo_dialogue_step,
		"accepted_wishes": accepted_wishes,
		"wish_progress": wish_progress,
		"bench_preview_path": last_bench_preview_path,
		"saved_at": Time.get_unix_time_from_system(),
		"playtime": total_playtime
	}

func get_debug_save_state() -> Dictionary:
	var state := _build_save_data(target_position.x, target_position.y)
	state.erase("saved_at")
	return state

func apply_debug_save_state(state: Dictionary) -> String:
	var type_by_key := {
		"has_needle": TYPE_BOOL,
		"collected_items": TYPE_ARRAY,
		"collected_modules": TYPE_ARRAY,
		"equipped_modules": TYPE_ARRAY,
		"saved_scene": TYPE_STRING,
		"intro_dialogue_played": TYPE_BOOL,
		"rant_needle_played": TYPE_BOOL,
		"player_is_sitting": TYPE_BOOL,
		"cocoon_saved_scene": TYPE_STRING,
		"cocoon_spawned": TYPE_BOOL,
		"broken_objects": TYPE_DICTIONARY,
		"defeated_bosses": TYPE_DICTIONARY,
		"defeated_enemies": TYPE_DICTIONARY,
		"discovered_locations": TYPE_DICTIONARY,
		"visited_rooms": TYPE_DICTIONARY,
		"has_talked_to_bella": TYPE_BOOL,
		"accepted_wishes": TYPE_ARRAY,
		"wish_progress": TYPE_DICTIONARY,
		"bench_preview_path": TYPE_STRING
	}
	for key in type_by_key:
		if state.has(key) and typeof(state[key]) != type_by_key[key]:
			return "Invalid value type for '%s'." % key

	var numeric_keys := ["max_health", "max_silk", "checkpoint_x", "checkpoint_y", "shards_collected", "cocoon_position_x", "cocoon_position_y", "cocoon_shards", "rubigo_dialogue_step", "playtime"]
	for key in numeric_keys:
		if state.has(key) and typeof(state[key]) != TYPE_INT and typeof(state[key]) != TYPE_FLOAT:
			return "Expected a number for '%s'." % key
	if int(state.get("max_health", player_max_health)) < 1:
		return "max_health must be at least 1."
	if int(state.get("max_silk", player_max_silk)) < 0:
		return "max_silk cannot be negative."
	var next_scene_path := str(state.get("saved_scene", scene_path))
	if not ResourceLoader.exists(next_scene_path, "PackedScene"):
		return "saved_scene must point to an existing scene."
	var next_cocoon_scene_path := str(state.get("cocoon_saved_scene", cocoon_scene_path))
	if not next_cocoon_scene_path.is_empty() and not ResourceLoader.exists(next_cocoon_scene_path, "PackedScene"):
		return "cocoon_saved_scene must be empty or point to an existing scene."

	player_max_health = int(state.get("max_health", player_max_health))
	player_max_silk = int(state.get("max_silk", player_max_silk))
	has_needle = bool(state.get("has_needle", has_needle))
	collected_items = Array(state.get("collected_items", collected_items), TYPE_STRING, &"", null)
	collected_modules = Array(state.get("collected_modules", collected_modules), TYPE_STRING, &"", null)
	equipped_modules = Array(state.get("equipped_modules", equipped_modules), TYPE_STRING, &"", null)
	target_position = Vector2(float(state.get("checkpoint_x", target_position.x)), float(state.get("checkpoint_y", target_position.y)))
	scene_path = str(state.get("saved_scene", scene_path))
	intro_dialogue_played = bool(state.get("intro_dialogue_played", intro_dialogue_played))
	rant_needle_played = bool(state.get("rant_needle_played", rant_needle_played))
	shards_collected = int(state.get("shards_collected", shards_collected))
	player_is_sitting = bool(state.get("player_is_sitting", player_is_sitting))
	cocoon_scene_path = str(state.get("cocoon_saved_scene", cocoon_scene_path))
	cocoon_position = Vector2(float(state.get("cocoon_position_x", cocoon_position.x)), float(state.get("cocoon_position_y", cocoon_position.y)))
	cocoon_spawned = bool(state.get("cocoon_spawned", cocoon_spawned))
	cocoon_shards = int(state.get("cocoon_shards", cocoon_shards))
	broken_objects = state.get("broken_objects", broken_objects)
	defeated_bosses = state.get("defeated_bosses", defeated_bosses)
	defeated_enemies = state.get("defeated_enemies", defeated_enemies)
	discovered_locations = state.get("discovered_locations", discovered_locations)
	visited_rooms = state.get("visited_rooms", visited_rooms)
	has_talked_to_bella = bool(state.get("has_talked_to_bella", has_talked_to_bella))
	rubigo_dialogue_step = int(state.get("rubigo_dialogue_step", rubigo_dialogue_step))
	accepted_wishes = state.get("accepted_wishes", accepted_wishes)
	wish_progress = state.get("wish_progress", wish_progress)
	last_bench_preview_path = str(state.get("bench_preview_path", last_bench_preview_path))
	total_playtime = float(state.get("playtime", total_playtime))

	_refresh_debug_player_state()
	if not save_game():
		return "Values applied, but the save file could not be written."
	return ""

func _refresh_debug_player_state() -> void:
	player_current_health = clampi(player_current_health, 0, player_max_health)
	player_current_silk = clampi(player_current_silk, 0, player_max_silk)
	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	player.set("maxHealth", player_max_health)
	player.set("maxSilk", player_max_silk)
	var current_health := clampi(int(player.get("currentHealth")), 0, player_max_health)
	var current_silk := clampi(int(player.get("currentSilk")), 0, player_max_silk)
	if player.has_method("set_current_health"):
		player.call("set_current_health", current_health)
	if player.has_method("set_current_silk"):
		player.call("set_current_silk", current_silk)
	var health_container := player.get("health_container") as Node
	if health_container:
		for child in health_container.get_children():
			health_container.remove_child(child)
			child.queue_free()
		if health_container.has_method("setMaxHearts"):
			health_container.call("setMaxHearts", player_max_health)
		if health_container.has_method("updateHearts"):
			health_container.call("updateHearts", current_health)
	var silk_container := player.get("silk_container") as Node
	if silk_container:
		for child in silk_container.get_children():
			silk_container.remove_child(child)
			child.queue_free()
		if silk_container.has_method("setMaxSilk"):
			silk_container.call("setMaxSilk", player_max_silk)
		if silk_container.has_method("updateSilk"):
			silk_container.call("updateSilk", current_silk)


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
		collected_modules = Array(save_data.get("collected_modules", []), TYPE_STRING, &"", null)
		var saved_modules: Array = save_data.get("equipped_modules", [])
		equipped_modules.clear()
		for slot_index in range(MODULE_SLOT_COUNT):
			var module_id = saved_modules[slot_index] if slot_index < saved_modules.size() else ""
			equipped_modules.append(module_id if collected_modules.has(module_id) else "")
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
		last_bench_preview_path = str(save_data.get("bench_preview_path", ""))
		
		cocoon_scene_path = save_data.get("cocoon_saved_scene", "")
		cocoon_position = Vector2(save_data.get("cocoon_position_x", 0.0), save_data.get("cocoon_position_y", 0.0))
		cocoon_spawned = save_data.get("cocoon_spawned", false)
		cocoon_shards = int(save_data.get("cocoon_shards", 0))
		
		broken_objects = save_data.get("broken_objects", {})
		defeated_bosses = save_data.get("defeated_bosses", {})
		defeated_enemies = save_data.get("defeated_enemies", {})
		discovered_locations = save_data.get("discovered_locations", {})
		visited_rooms = save_data.get("visited_rooms", {})
		
		has_talked_to_bella = save_data.get("has_talked_to_bella", false)
	
		rubigo_dialogue_step = save_data.get("rubigo_dialogue_step", 0)
	
		# 4. Load the level
		var level_to_load = save_data.get("saved_scene", scene_path)
		get_tree().change_scene_to_file(level_to_load)
		
		print("Game loaded from slot ", slot_to_use, "! Player restored to full health.")
		return true

func is_boss_defeated(boss_id: String) -> bool:
	return bool(defeated_bosses.get(boss_id, false))

func mark_boss_defeated(boss_id: String) -> void:
	if boss_id.is_empty() or is_boss_defeated(boss_id):
		return
	defeated_bosses[boss_id] = true
	defeated_enemies[boss_id] = true
	save_game(false)

func is_enemy_defeated(enemy_id: String) -> bool:
	return bool(defeated_enemies.get(enemy_id, false) or defeated_bosses.get(enemy_id, false))

func mark_enemy_defeated(enemy_id: String) -> void:
	if enemy_id.is_empty() or is_enemy_defeated(enemy_id):
		return
	defeated_enemies[enemy_id] = true
	save_game(false)

func enter_region(region_id: String, region_display_name: String, show_first_visit_banner: bool = true, subregion_display_name: String = "") -> void:
	# Give every room in one region the same ID; different regions use different IDs.
	if region_id.is_empty():
		return

	var room_is_new: bool = not current_scene_path.is_empty() and not has_visited_room(current_scene_path)
	if room_is_new:
		visited_rooms[current_scene_path] = true

	var region_was_discovered: bool = bool(discovered_locations.get(region_id, false))
	if not region_was_discovered:
		discovered_locations[region_id] = true
		if show_first_visit_banner:
			save_game()
			_show_region_banner(LOCATION_BANNER, region_display_name)
	elif subregion_display_name.is_empty() and region_transition_pending and transition_origin_region_id != region_id:
		_show_region_banner(REGION_RETURN_BANNER, region_display_name)
	if room_is_new and (region_was_discovered or not show_first_visit_banner):
		save_game(false)

	if not subregion_display_name.is_empty():
		_show_region_banner(REGION_RETURN_BANNER, subregion_display_name)

	current_region_id = region_id
	transition_origin_region_id = ""
	region_transition_pending = false

func has_visited_room(room_path: String) -> bool:
	return bool(visited_rooms.get(room_path, false))

func _show_region_banner(banner_scene: PackedScene, region_display_name: String) -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return

	var banner = banner_scene.instantiate()
	current_scene.add_child(banner)
	banner.display_title(region_display_name)

# Funkcja do zmieniania sceny z ustawieniem pozycji
func change_scene_to_position(scene_path: String, new_x: float, new_y: float):
	transition_origin_region_id = current_region_id
	region_transition_pending = true
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
				meta = {
					"slot": i,
					"exists": true,
					"scene": d.get("saved_scene", ""),
					"checkpoint_x": d.get("checkpoint_x", 0),
					"checkpoint_y": d.get("checkpoint_y", 0),
					"bench_preview_path": d.get("bench_preview_path", ""),
					"saved_at": d.get("saved_at", 0),
					"playtime": d.get("playtime", 0.0)
				}
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
