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

enum ItemType { NEEDLE, COGWORK_BATTERY, KEY_TO_LAB_21, HEALTH_UPGRADE, SILK_UPGRADE }
var collected_items: Array[String] = []

# Funkcja do zmieniania sceny z ustawieniem pozycji
func change_scene_to_position(scene_path: String, new_x: float, new_y: float):
	target_position = Vector2(new_x, new_y)
	should_reposition = true
	get_tree().change_scene_to_file(scene_path)
