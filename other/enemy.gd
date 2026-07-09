extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var silk_container: HBoxContainer = $"../CanvasLayer/SilkContainer"
const SHARD_SCENE = preload("res://other/shard.tscn")

@export var speed = 100
@export var limit = 0.5
@export var endPoint: Marker2D

var startPosition
var endPosition

@export var max_health: int = 3
var current_health: int = max_health

@export var min_shards_dropped: int = 2
@export var max_shards_dropped: int = 5

func _ready():
	startPosition = position
	#endPosition = startPosition + Vector2(200, 0)
	endPosition = endPoint.global_position
	animated_sprite_2d.flip_h = true
	
func take_damage(amount: int):
	current_health -= amount
	if (Global.player_current_silk < Global.player_max_silk):
		Global.player_current_silk += 1
		var player = get_tree().get_first_node_in_group("player")
		player.set_current_silk(Global.player_current_silk)
		silk_container.updateSilk(Global.player_current_silk)
	
	# Visual feedback: Flash white quickly when hit
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(100, 100, 100), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1), 0.1)
	
	if current_health <= 0:
		die_and_drop_shards()
		
func die_and_drop_shards():
	# Determine a random amount of shards to scatter
	var drop_count = randi_range(min_shards_dropped, max_shards_dropped)
	
	for i in range(drop_count):
		var shard_instance = SHARD_SCENE.instantiate() as RigidBody2D
		
		# Set its initial starting point to match the enemy's location
		shard_instance.global_position = global_position
		
		# Add it to the world level (root scene) so it doesn't vanish when the enemy is freed
		get_parent().add_child(shard_instance)
		
		# Blast them outwards and upwards randomly!
		var launch_force_x = randf_range(-250.0, 250.0)
		var launch_force_y = randf_range(-400.0, -600.0) # Negative Y is upward
		
		shard_instance.linear_velocity = Vector2(launch_force_x, launch_force_y)
	
	# Finally, delete the enemy from the scene
	queue_free()
	
func changeDirection():
	var tempStart = startPosition
	startPosition = endPosition
	endPosition = tempStart
	
func updateVelocity():
	var moveDirection = endPosition - position
	if moveDirection.length() < limit :
		changeDirection()
		if animated_sprite_2d.flip_h == true:
			animated_sprite_2d.flip_h = false
		else:
			animated_sprite_2d.flip_h = true
			
	velocity = moveDirection.normalized() * speed
	
func _physics_process(delta: float) -> void:
	updateVelocity()
	move_and_slide()
