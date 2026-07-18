extends CharacterBody2D
@onready var rant: AnimatedSprite2D = $rant
@onready var dialogue: CanvasLayer = $"../CanvasLayer/Dialogue"
@onready var health_container: HBoxContainer = $"../CanvasLayer/HealthContainer"
@onready var silk_container: HBoxContainer = $"../CanvasLayer/SilkContainer"
@onready var attack_collision: CollisionShape2D = $AttackArea/CollisionShape2D

@onready var startHealth: int = 5
@onready var startSilk: int = 0

@export var maxHealth: int = 5
@onready var currentHealth: int = startHealth

@export var maxSilk: int = 5
@onready var currentSilk: int = startSilk

@onready var wall_detector: RayCast2D = $AttackArea/WallDetector
@onready var ledge_detector: RayCast2D = $AttackArea/LedgeDetector

var is_attacking: bool = false
var is_invincible: bool = false
var is_sitting: bool = false
var is_transitioning: bool = false
var is_dead: bool = false
var is_wren_active: bool = false
var fade_layer: CanvasLayer = null
var fade_rect: ColorRect = null
var is_climbing: bool = false
var can_climb: bool = true

const SPEED = 300.0
const RUN_SPEED = 600.0
const JUMP_VELOCITY = -1400.0

const DIALOGUE_FILE = preload("res://dialogue/rant_needle.dialogue")

func _ready():
	currentHealth = Global.player_current_health
	maxHealth = Global.player_max_health
	currentSilk = Global.player_current_silk
	maxSilk = Global.player_max_silk
	
	# Save the reposition state before clearing it
	var should_fade_in = Global.should_reposition
	
	# Check if player should be sitting before playing arrival animation
	var should_start_sitting = Global.player_is_sitting
	
	if Global.should_go_back_to_checkpoint:
		# If we are returning to a checkpoint, fade out the screen first
		global_position = Global.target_position
		Global.should_go_back_to_checkpoint = false
	elif Global.should_reposition:
		if Global.current_target_position != Vector2.ZERO:
			global_position = Global.current_target_position
		else:
			global_position = Global.target_position
			
		rant.flip_h = Global.player_facing_right
		$AttackArea.scale.x = 1 if Global.player_facing_right else -1
		
		#callable(func(): global_position = Global.target_position).call_deferred()
		# Resetujemy zmienną, aby nie teleportować gracza przy zwykłym starcie gry
		Global.should_reposition = false
		# Only play standing arrival animation if not starting in sitting state
		if not should_start_sitting:
			play_arrival_animation()
		else:
			# If sitting, just transition without the standing animation
			is_transitioning = true
			await get_tree().create_timer(0.1).timeout
			is_transitioning = false
		
	attack_collision.disabled = true
	
	# If we just respawned via checkpoint (and screen was faded to black), fade back in
	if should_fade_in:
		velocity.x = SPEED * (1.0 if Global.player_facing_right else -1.0)
		await create_fade_in(0.8)
	
	# If player was sitting at the checkpoint when saved, restore sitting state
	if should_start_sitting:
		is_sitting = true
		velocity = Vector2.ZERO
		# Play sitting animation
		var anim_suffix := "" if Global.has_needle else "_no_needle"
		rant.animation = "sit" + anim_suffix
		# Reset the flag so it doesn't carry over to other loads
		Global.player_is_sitting = false
	

func _physics_process(delta: float) -> void:
	if is_climbing:
		return # Skip all gravity, inputs, and slide collisions while climbing!
			
	# Run our check every frame we are mid-air
	check_ledge_climb()

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
	
	# If wren ability is active, block input and movement
	if is_wren_active:
		velocity = Vector2.ZERO
		return
	
	if is_transitioning:
		return
			
	if is_sitting:
		velocity = Vector2.ZERO
		# If player tries to move or jump, stand up
		if Input.is_action_pressed("jump") or Input.get_axis("left", "right") != 0:
			is_sitting = false
			Global.player_is_sitting = false
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
		if not Global.rant_needle_played:
			Global.rant_needle_played = true
			Global.save_game() # Permanently remember they did this
			
			# Trigger the dialogue node attached to your level
			if dialogue and dialogue.has_method("start"):
				dialogue.start(DIALOGUE_FILE, "rant_needle")
		
		is_attacking = true
		rant.play("attack")
		attack_collision.disabled = false 

		await get_tree().create_timer(0.5).timeout
		
		attack_collision.disabled = true 
		is_attacking = false

	# 3. WREN ABILITY - Convert 5 silk to 5 health
	if Input.is_action_just_pressed("wren") and not is_wren_active and not is_attacking and currentSilk >= 5:
		is_wren_active = true
		# Consume silk and restore health
		currentSilk -= 5
		currentHealth = min(currentHealth + 5, maxHealth) # Cap health at max
		Global.player_current_silk = currentSilk
		Global.player_current_health = currentHealth
		# Update HUD
		if health_container and health_container.has_method("updateHearts"):
			health_container.updateHearts(currentHealth)
		# Update silk HUD if available
		var silk_container = get_node_or_null("../CanvasLayer/SilkContainer")
		if silk_container and silk_container.has_method("updateSilk"):
			silk_container.updateSilk(currentSilk)
		# Play wren animation and effects
		rant.play("wren")
		# Flash effect during wren
		var tw = create_tween()
		tw.tween_property(rant, "modulate:a", 0.5, 0.1)
		tw.tween_property(rant, "modulate:a", 1.0, 0.1)
		tw.set_loops(3) # Flash 3 times
		# Wait for animation and flash to finish
		await get_tree().create_timer(0.8).timeout
		is_wren_active = false

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
		# Mark that player should respawn in cocoon (they'll break free to get max silk)
		Global.cocoon_spawned = true
		Global.cocoon_scene_path = get_tree().current_scene.scene_file_path
		Global.cocoon_position = global_position
		Global.should_go_back_to_checkpoint = true
		Global.save_game()
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
	
func sit_on_bench() -> void:
	is_sitting = true
	velocity = Vector2.ZERO

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

# Called when cocoon breaks - restore player and grant max silk
func break_cocoon() -> void:
	set_current_silk(maxSilk)  # Grant max silk for breaking free
	silk_container.updateSilk(currentSilk)

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1)
	elif body.is_in_group("cocoon") and body.has_method("take_cocoon_damage"):
		body.take_cocoon_damage(1)
	elif body.is_in_group("breakable") and body.has_method("take_damage"):
		body.take_damage(1)
		
func _on_attack_area_area_entered(area: Area2D) -> void:
	# Check if the player's attack hit the Cocoon Area2D
	if area.is_in_group("cocoon") and area.has_method("take_cocoon_damage"):
		area.take_cocoon_damage(1)
	if area.is_in_group("breakable") and area.has_method("take_damage"):
		area.take_damage(1)
		
		
func check_ledge_climb():
	# If the player is back on the ground, reset their ability to climb again
	if is_on_floor():
		can_climb = true
		return
		
	# If they are already climbing or already used up their climb this jump, block it
	if is_climbing or not can_climb:
		return
	
	# If we are pressing against a wall, but our head is clear of the top edge
	if wall_detector.is_colliding() and not ledge_detector.is_colliding():
		can_climb = false # Immediately consume the climb charge!
		start_ledge_climb()

func start_ledge_climb():
	is_climbing = true
	velocity = Vector2.ZERO # Halt physics movement
	
	# Play your climb animation here if you have one
	# rant.play("climb") 
	
	# Determine which direction we are facing to calculate the step forward
	var direction_modifier = 1.0 if Global.player_facing_right else -1.0
	
	# Calculate target position: Up over the ledge and slightly forward onto it
	var target_pos = global_position + Vector2(30 * direction_modifier, -100)
	
	# Smoothly move the player onto the platform using a Tween
	var tween = create_tween()
	
	# Optional: Break it into two steps (Up, then Forward) for a cleaner mechanical feel
	tween.tween_property(self, "global_position:y", global_position.y - 150, 0.2)
	tween.tween_property(self, "global_position:x", global_position.x + (30 * direction_modifier), 0.1)
	
	await tween.finished
	is_climbing = false
