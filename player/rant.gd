extends CharacterBody2D
@onready var rant: AnimatedSprite2D = $rant
@onready var dialogue: CanvasLayer = $"../Dialogue"
@onready var health_container: HBoxContainer = $"../CanvasLayer/HealthContainer"
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

@onready var startHealth: int = 5
@onready var startSilk: int = 0

@export var maxHealth: int = 5
@onready var currentHealth: int = startHealth

@export var maxSilk: int = 5
@onready var currentSilk: int = startSilk

var is_attacking: bool = false
var is_invincible: bool = false
var is_sitting: bool = false
var is_transitioning: bool = false
var is_dead: bool = false
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null

const SPEED = 300.0
const RUN_SPEED = 600.0
const JUMP_VELOCITY = -1400.0

func _ready():
	currentHealth = Global.player_current_health
	maxHealth = Global.player_max_health
	currentSilk = Global.player_current_silk
	maxSilk = Global.player_max_silk
	
	# Save the reposition state before clearing it
	var should_fade_in = Global.should_reposition
	
	if Global.should_reposition:
		global_position = Global.target_position
		#callable(func(): global_position = Global.target_position).call_deferred()
		# Resetujemy zmienną, aby nie teleportować gracza przy zwykłym starcie gry
		Global.should_reposition = false
		play_arrival_animation()
		
	attack_collision.disabled = true
	
	# If we just respawned via checkpoint (and screen was faded to black), fade back in
	if should_fade_in:
		await create_fade_in(0.8)


func _physics_process(delta: float) -> void:
	if Global.is_dialogue_active:
		velocity.x = move_toward(velocity.x, 0, SPEED) # Slow down to a stop if running
		if not is_on_floor():
			velocity += get_gravity() * delta # Allow gravity so player doesn't float
		move_and_slide()
		
		# Force idle animation
		var anim_suffix := "" if Global.has_needle else "_no_needle"
		rant.animation = "idle" + anim_suffix
		return

	# If player is dead, block input and movement
	if is_dead:
		velocity = Vector2.ZERO
		return
	
	if is_transitioning:
		return
			
	if is_sitting:
		velocity = Vector2.ZERO
		# If player tries to move or jump, stand up
		if Input.is_action_just_pressed("jump") or Input.get_axis("left", "right") != 0:
			is_sitting = false
		else:
			# Enforce sitting animation loop
			var anim_suffix := "" if Global.has_needle else "_no_needle"
			rant.animation = "sit" + anim_suffix
			move_and_slide()
			return # Skip the rest of the movement code
		
	var current_speed = SPEED
	
	# 1. DYNAMIC ANIMATION HANDLING
	if not is_attacking:
		# If we have the needle, suffix is "". If not, suffix is "_no_needle"
		var anim_suffix := "" if Global.has_needle else "_no_needle"
		
		if velocity.x > SPEED or velocity.x < -SPEED:
			rant.animation = "run" + anim_suffix
		elif velocity.x > 1 or velocity.x < -1:
			rant.animation = "walk" + anim_suffix
		else:
			rant.animation = "idle" + anim_suffix

	# 2. GATED ATTACK INPUT
	# Added "and Global.has_needle" so clicking 'X' does nothing without it!
	if Input.is_action_just_pressed("attack") and not is_attacking and Global.has_needle:
		is_attacking = true
		rant.play("attack")
		attack_collision.disabled = false 

		await get_tree().create_timer(0.5).timeout
		
		attack_collision.disabled = true 
		is_attacking = false

	# Run modifier
	if Input.is_action_pressed("run"):
		current_speed = RUN_SPEED     

	# Gravity
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Movement input
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

	move_and_slide()

	# Sprite & Hitbox flipping
	if direction == 1.0:
		rant.flip_h = true
		$AttackArea.scale.x = 1
	elif direction == -1.0:
		rant.flip_h = false
		$AttackArea.scale.x = -1

	handleCollision()

func handleCollision():
	# If player recently took damage, don't check for more yet
	if is_invincible:
		return

	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Pro tip: Put your enemy nodes into a Group called "enemies" in the Godot inspector!
		if collider.is_in_group("enemies"):
			take_damage(1)
			break # Break loop early so we don't process multiple collisions at once

func take_damage(amount: int):
	is_invincible = true
	# Prevent further damage triggers once dead
	if is_dead:
		return

	currentHealth -= amount

	# If health reaches zero or below -> trigger game over (load last saved state)
	if currentHealth <= 0:
		is_dead = true
		is_invincible = true
		# Stop any ongoing attack and disable hitbox
		is_attacking = false
		attack_collision.disabled = true
		rant.play("death")
		# Flash the player a few times to indicate death
		var tw_death = create_tween()
		tw_death.tween_property(rant, "modulate:a", 0.2, 0.12)
		tw_death.tween_property(rant, "modulate:a", 1.0, 0.12)
		tw_death.set_loops(6)
		# Wait for the blinking to finish (and any short death animation)
		await tw_death.finished
		# Smooth fade to black before loading save
		await create_fade_out(0.6)
		# Load the last saved state (Global.load_game will change scene to the saved checkpoint)
		Global.load_game()
		return

	# Normal damage flow: update global and HUD, flash invincibility
	Global.player_current_health = currentHealth
	health_container.updateHearts(currentHealth)

	var tw = create_tween()
	tw.tween_property(rant, "modulate:a", 0.5, 0.1)
	tw.tween_property(rant, "modulate:a", 1.0, 0.1)
	tw.set_loops(5) # Flash 5 times

	await get_tree().create_timer(1.0).timeout
	is_invincible = false
	
func play_entrance_animation() -> void:
	is_transitioning = true
	velocity = Vector2.ZERO
	var anim_suffix := "" if Global.has_needle else "_no_needle"
	rant.play("back" + anim_suffix)
	# Wait briefly for the animation to look meaningful before screen fades
	await get_tree().create_timer(0.1).timeout 

func play_arrival_animation() -> void:
	is_transitioning = true
	var anim_suffix := "" if Global.has_needle else "_no_needle"
	rant.play("front" + anim_suffix)
	# Lock player for a moment while facing screen
	await get_tree().create_timer(0.1).timeout 
	is_transitioning = false

# Public helper to set the player's current health from other systems
func set_current_health(new_health: int) -> void:
	currentHealth = new_health
	Global.player_current_health = currentHealth
	# Update HUD immediately
	if health_container and health_container.has_method("updateHearts"):
		health_container.updateHearts(currentHealth)

# Public helper to set the player's current silk from other systems
func set_current_silk(new_silk: int) -> void:
	currentSilk = new_silk
	Global.player_current_silk = currentSilk

# Create a fade layer with ColorRect for screen fade effects
func create_fade_layer() -> void:
	if fade_layer != null:
		return # Already created
	
	fade_layer = CanvasLayer.new()
	fade_layer.layer = 1000 # High layer so it's on top
	add_child(fade_layer)
	
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0, 0, 0, 0) # Start transparent
	fade_rect.anchor_left = 0
	fade_rect.anchor_top = 0
	fade_rect.anchor_right = 1
	fade_rect.anchor_bottom = 1
	fade_layer.add_child(fade_rect)

# Fade to black (used before loading save on death)
func create_fade_out(duration: float = 0.5) -> void:
	create_fade_layer()
	var tw = create_tween()
	tw.tween_property(fade_rect, "color", Color(0, 0, 0, 1.0), duration)
	await tw.finished

# Fade from black (used after loading save on respawn)
func create_fade_in(duration: float = 0.5) -> void:
	create_fade_layer()
	# Start at full black, fade to transparent
	fade_rect.color = Color(0, 0, 0, 1.0)
	var tw = create_tween()
	tw.tween_property(fade_rect, "color", Color(0, 0, 0, 0.0), duration)
	await tw.finished
	cleanup_fade()

# Clean up fade layer when no longer needed
func cleanup_fade() -> void:
	if fade_layer != null:
		fade_layer.queue_free()
		fade_layer = null
		fade_rect = null

func sit_on_bench() -> void:
	is_sitting = true
	velocity = Vector2.ZERO

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1)
