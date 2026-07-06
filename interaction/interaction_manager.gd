extends Node2D

@onready var player = get_tree().get_first_node_in_group("player")
@onready var label = $Label
@onready var decor = $Decor

const base_text = "↑ "

var active_areas = []
var can_interact = true

enum {FADE_IN, FADE_OUT}

func register_area(area: InteractionArea):
	active_areas.push_back(area)
	
func unregister_area(area: InteractionArea):
	var index = active_areas.find(area)
	if (index != -1) :
		active_areas.remove_at(index)


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if active_areas.size() > 0 && can_interact:
		active_areas.sort_custom(_sort_by_distance_to_player)
		label.text = base_text + active_areas[0].action_name
		label.global_position = active_areas[0].global_position
		label.global_position.y += 55
		label.global_position.x -= label.size.x / 2
		label.fade(0.5, FADE_IN)
		decor.global_position = active_areas[0].global_position
		decor.global_position.y += 65
		decor.fade(0.5, FADE_IN)
		#decor.show()
	else:
		#label.hide()
		label.fade(0.1, FADE_OUT)
		decor.fade(0.1, FADE_OUT)
		#decor.hide()
		
func _sort_by_distance_to_player(area1, area2):
	var area1_to_player = player.global_position.distance_to(area1.global_position)
	var area2_to_player = player.global_position.distance_to(area2.global_position)
	return area1_to_player < area2_to_player
	
func _input(event):
	if event.is_action_pressed("interact") && can_interact:
		if active_areas.size() > 0:
			#can_interact = false
			#label.hide()
			
			await active_areas[0].interact.call()
			
			can_interact = true
