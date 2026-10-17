extends Node2D

const GUARDIAN_EDGE_GAP: float = 200.0

@onready var dialogue = $Dialogue
@onready var health_container: HBoxContainer = $CanvasLayer/HealthContainer
@onready var silk_container: HBoxContainer = $CanvasLayer/SilkContainer
@onready var character_body_2d: CharacterBody2D = $CharacterBody2D
@onready var tangled_guardian: CharacterBody2D = get_node_or_null("TangledGuardian")
@onready var boss_exit_blocker: CollisionShape2D = get_node_or_null("BossExitBlocker/CollisionShape2D")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	Global.current_scene_path = scene_file_path
	health_container.setMaxHearts(character_body_2d.maxHealth)
	silk_container.setMaxSilk(character_body_2d.maxSilk)
	health_container.updateHearts(character_body_2d.currentHealth)
	silk_container.updateSilk(character_body_2d.currentSilk)
	if tangled_guardian:
		_lock_boss_room_exits()
		_set_guardian_arena_bounds()
		if tangled_guardian.has_signal("defeated"):
			tangled_guardian.connect("defeated", _on_tangled_guardian_defeated)
	
	if Global.cocoon_spawned and Global.cocoon_scene_path == get_tree().current_scene.scene_file_path:
		spawn_persistant_cocoon()

func _lock_boss_room_exits() -> void:
	for transition_zone in get_tree().get_nodes_in_group("room_transitions"):
		transition_zone.call("set_transition_enabled", false)

func _set_guardian_arena_bounds() -> void:
	var room_camera := get_node_or_null("CharacterBody2D/Camera2D") as Camera2D
	if room_camera == null:
		return
	var guardian_collision := tangled_guardian.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var horizontal_margin := 0.0
	if guardian_collision and guardian_collision.shape is CapsuleShape2D:
		var guardian_capsule := guardian_collision.shape as CapsuleShape2D
		horizontal_margin = guardian_capsule.radius * absf(tangled_guardian.global_scale.x * guardian_collision.scale.x)
	var edge_margin := horizontal_margin + GUARDIAN_EDGE_GAP
	tangled_guardian.set("arena_left_limit", room_camera.limit_left + edge_margin)
	tangled_guardian.set("arena_right_limit", room_camera.limit_right - edge_margin)

func _on_tangled_guardian_defeated() -> void:
	for transition_zone in get_tree().get_nodes_in_group("room_transitions"):
		transition_zone.call("set_transition_enabled", true)
	if boss_exit_blocker:
		boss_exit_blocker.set_deferred("disabled", true)
	
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
