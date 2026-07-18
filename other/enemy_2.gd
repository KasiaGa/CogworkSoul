extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var silk_container: HBoxContainer = $"../CanvasLayer/SilkContainer"
const SHARD_SCENE = preload("res://other/shard.tscn")

@export var speed = 100
@export var limit = 5.0 # Increased slightly to ensure target detection works smoothly
@export var endPoint: Marker2D
@export var pause_time: float = 0.2 # How long to wait at each end point

# Wiggle settings
@export var wiggle_amplitude: float = 15.0 # How far left/right it wiggles
@export var wiggle_frequency: float = 8.0   # How fast it wiggles

var startPosition
var endPosition
var is_paused: bool = false
var time_passed: float = 0.0

@export var max_health: int = 3
var current_health: int = max_health

@export var min_shards_dropped: int = 4
@export var max_shards_dropped: int = 5

func _ready():
	startPosition = position
	endPosition = endPoint.global_position
	animated_sprite_2d.flip_h = true
	
func take_damage(amount: int):
	current_health -= amount
	if (Global.player_current_silk < Global.player_max_silk):
		Global.player_current_silk += 1
		var player = get_tree().get_first_node_in_group("player")
		player.set_current_silk(Global.player_current_silk)
		silk_container.updateSilk(Global.player_current_silk)
	
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(100, 100, 100), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1), 0.1)
	
	if current_health <= 0:
		die_and_drop_shards()
		
func die_and_drop_shards():
	var drop_count = randi_range(min_shards_dropped, max_shards_dropped)
	
	for i in range(drop_count):
		var shard_instance = SHARD_SCENE.instantiate() as RigidBody2D
		shard_instance.global_position = global_position
		get_parent().add_child(shard_instance)
		
		var launch_force_x = randf_range(-250.0, 250.0)
		var launch_force_y = randf_range(-400.0, -600.0)
		
		shard_instance.linear_velocity = Vector2(launch_force_x, launch_force_y)
	
	queue_free()
	
func changeDirection():
	var tempStart = startPosition
	startPosition = endPosition
	endPosition = tempStart
	
	# Handle pausing at the end point
	start_pause_timer()

func start_pause_timer():
	is_paused = true
	velocity = Vector2.ZERO
	
	# Reset the sprite's visual wiggle back to center while resting
	animated_sprite_2d.position.x = 0
	
	# Play a resting animation here if you have one (e.g., animated_sprite_2d.play("idle"))
	
	await get_tree().create_timer(pause_time).timeout
	
	is_paused = false
	# Flip the sprite direction after the pause concludes
	animated_sprite_2d.flip_h = !animated_sprite_2d.flip_h

func updateVelocity(delta: float):
	if is_paused:
		return
		
	var moveDirection = endPosition - position
	
	# If we are close enough to the target point, swap targets
	if moveDirection.length() < limit:
		changeDirection()
		return
			
	velocity = moveDirection.normalized() * speed
	
	# Apply visual horizontal wiggle to the sprite node while moving
	time_passed += delta
	animated_sprite_2d.position.x = sin(time_passed * wiggle_frequency) * wiggle_amplitude
	
func _physics_process(delta: float) -> void:
	updateVelocity(delta)
	move_and_slide()
