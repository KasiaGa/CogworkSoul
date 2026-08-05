extends RigidBody2D

@export var bell_textures: Array[Texture2D] = []

@export var push_force: float = 120.0
@export var spin_force: float = 180.0
@export var min_celocity_for_sound: float = 20.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var audio_player: AudioStreamPlayer = $AudioStreamPlayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if bell_textures.size() > 0:
		var random_index = randi() % bell_textures.size()
		sprite.texture = bell_textures[random_index]
		
	sprite.flip_h = randf() > 0.5
	
	contact_monitor = true
	max_contacts_reported = 1
	body_entered.connect(_on_body_entered)

func apply_kick(player_velocity_x: float):
	var direction = sign(player_velocity_x)
	if direction == 0:
		direction = 1 # Default to right if player is stationary
	
	var push_dir = Vector2(direction, -1.3).normalized()
	apply_central_impulse(push_dir * push_force)
	
	var random_spin = randf_range(-spin_force, spin_force)
	apply_torque_impulse(random_spin)

func _on_body_entered(body) -> void:
	if body.is_in_group("player"):
		var player_velocity = body.velocity.x if "velocity" in body else 100.0
		apply_kick(player_velocity)
	if linear_velocity.length() > min_celocity_for_sound:
		if audio_player and audio_player.stream and not audio_player.playing:
			audio_player.play()
