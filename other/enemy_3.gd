extends CharacterBody2D

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var silk_container: HBoxContainer = $"../CanvasLayer/SilkContainer"

const SHARD_SCENE = preload("res://other/shard.tscn")
const JOURNAL_ENEMY_ID: String = "factory_stalker"

@export var follow_speed: float = 120.0
@export var acceleration: float = 600.0
@export var max_health: int = 3
@export var min_shards_dropped: int = 4
@export var max_shards_dropped: int = 5

var current_health: int = max_health
var hit_count: int = 0
var player: Node2D

func _ready() -> void:
	animated_sprite_2d.flip_h = true
	_find_player()

func _find_player() -> void:
	player = get_tree().get_first_node_in_group("player") as Node2D

func _physics_process(delta: float) -> void:
	if not is_instance_valid(player):
		_find_player()

	var desired_velocity := Vector2.ZERO
	if is_instance_valid(player):
		var direction: Vector2 = player.global_position - global_position
		if not direction.is_zero_approx():
			desired_velocity = direction.normalized() * follow_speed
			if abs(direction.x) > 1.0:
				animated_sprite_2d.flip_h = direction.x > 0.0

	velocity = velocity.move_toward(desired_velocity, acceleration * delta)
	move_and_slide()

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	hit_count += 1
	amount = Global.get_enemy_hit_damage(hit_count, amount)
	current_health -= amount

	if Global.player_current_silk < Global.player_max_silk:
		Global.player_current_silk += 1
		var player_character = get_tree().get_first_node_in_group("player")
		player_character.set_current_silk(Global.player_current_silk)
		silk_container.updateSilk(Global.player_current_silk)

	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(100, 100, 100), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1), 0.1)

	if current_health <= 0:
		die_and_drop_shards()

func die_and_drop_shards() -> void:
	Global.mark_enemy_defeated(JOURNAL_ENEMY_ID)
	var drop_count = Global.get_enemy_shard_drop_count(min_shards_dropped, max_shards_dropped)
	for _index in range(drop_count):
		var shard_instance = SHARD_SCENE.instantiate() as RigidBody2D
		shard_instance.global_position = global_position
		get_parent().add_child(shard_instance)
		shard_instance.linear_velocity = Vector2(randf_range(-250.0, 250.0), randf_range(-600.0, -400.0))
	queue_free()