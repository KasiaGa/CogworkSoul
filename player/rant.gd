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

@onready var weapon_tip: Node2D = $AttackArea/WeaponTip
@onready var slash_trail: Line2D = $AttackArea/SlashTrail

@onready var attack_sfx: AudioStreamPlayer = $AttackSfx
@onready var wren_sfx: AudioStreamPlayer = $WrenSfx
@onready var hurt_sfx: AudioStreamPlayer = $HurtSfx
@onready var talk_sfx: AudioStreamPlayer = $TalkSfx
@onready var surprised_sfx: AudioStreamPlayer = $SurprisedSfx
@onready var walk_sfx: AudioStreamPlayer = $WalkSfx
@onready var sit_sfx: AudioStreamPlayer = $SitSfx

@export var attack_sounds: Array[AudioStream] = []
@export var wren_sounds: Array[AudioStream] = []
@export var hurt_sounds: Array[AudioStream] = []
@export var talk_sounds: Array[AudioStream] = []
@export var surprised_sounds: Array[AudioStream] = []
@export var walk_sounds: Array[AudioStream] = []
@export var sit_sounds: Array[AudioStream] = []

var base_scale: Vector2 = Vector2.ONE

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
var is_currently_running: bool = false
var was_on_floor: bool = true
var squash_tween: Tween = null
var air_time: float = 0.0

var trail_points: Array[Vector2] = []
var max_trail_points: int = 10

const SPEED = 300.0
const RUN_SPEED = 600.0
const JUMP_VELOCITY = -1400.0

const DIALOGUE_FILE = preload("res://dialogue/rant_needle.dialogue")

func _ready():
	base_scale = rant.scale
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
	
	# Handle intro animations (lie and get_up)
	if Global.should_play_lie_animation:
		var anim_suffix := "" if Global.has_needle else "_no_needle"
		rant.animation = "lie" + anim_suffix
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if Global.should_play_get_up_animation:
		var anim_suffix := "" if Global.has_needle else "_no_needle"
		rant.animation = "get_up" + anim_suffix
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if Global.is_dialogue_active:
		# Immediately stop footstep SFX when dialogue is active to avoid bleed-through
		if walk_sfx.playing:
			walk_sfx.stop()
		velocity.x = move_toward(velocity.x, 0, SPEED) # Slow down to a stop if running
		if not is_on_floor():
			velocity += get_gravity() * delta # Allow gravity so player doesn't float
		move_and_slide()
		
#		if talk_sounds.size() > 0:
#			talk_sfx.stream = talk_sounds.pick_random()
#			talk_sfx.play()
		
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
			handle_footstep_sfx(true)
		elif velocity.x > 1 or velocity.x < -1:
			rant.animation = "walk" + anim_suffix
			handle_footstep_sfx(false)
		else:
			rant.animation = "idle" + anim_suffix
			if walk_sfx.playing:
				walk_sfx.stop()
	else:
		if walk_sfx.playing:
			walk_sfx.stop()
			
	if is_attacking and weapon_tip and slash_trail:
		# Capture the current animated position of WeaponTip
		trail_points.append(slash_trail.to_local(weapon_tip.global_position))
		
		# Limit the trail length (adjust max_trail_points as needed)
		if trail_points.size() > max_trail_points:
			trail_points.pop_front()
			
		slash_trail.points = trail_points
	else:
		# Fade out the trail when the attack ends
		if trail_points.size() > 0:
			trail_points.pop_front()
			slash_trail.points = trail_points

	# 2. GATED ATTACK INPUT
	# Added "and Global.has_needle" so clicking 'X' does nothing without it!
	if Input.is_action_just_pressed("attack") and not is_attacking and Global.has_needle:
		if not Global.rant_needle_played:
			Global.rant_needle_played = true
			Global.save_game()
			if dialogue and dialogue.has_method("start"):
				dialogue.start(DIALOGUE_FILE, "rant_needle")
		
		is_attacking = true
		
		# 1. FORCE CLEAR the trail points so old points don't confuse the new swing
		trail_points.clear()
		if slash_trail:
			slash_trail.points = []

		# 2. RESTART the AnimationPlayer from 0.0 seconds
		if $AnimationPlayer.is_playing():
			$AnimationPlayer.stop()
		$AnimationPlayer.play("attack_trail")

		# 3. Play sprite attack animation
		rant.play("attack")
		attack_collision.disabled = false 
		
		if attack_sounds.size() > 0:
			attack_sfx.stream = attack_sounds.pick_random()
			attack_sfx.play()

		await get_tree().create_timer(0.3).timeout 
		
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
		
		if wren_sounds.size() > 0:
			wren_sfx.stream = wren_sounds.pick_random()
			wren_sfx.play()
		
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
	if not is_on_floor():
		air_time += delta
	else:
		# Only trigger landing squash if airborne for more than 0.1 seconds (ignores tile seams)
		if air_time > 0.1:
			var impact_factor = clamp(remap(velocity.y, 0, 1500, 0.95, 0.9), 0.9, 0.95)
			var stretch_x = 1.0 + (1.0 - impact_factor)
			apply_squash_and_stretch(Vector2(stretch_x, impact_factor), 0.05, 0.15)
		
		# Reset the timer as long as we stay grounded
		air_time = 0.0
		
	was_on_floor = is_on_floor()

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		# Vertical stretch on jump takeoff
		apply_squash_and_stretch(Vector2(0.9, 1.1), 0.08, 0.15)

	# Movement input
	var direction := Input.get_axis("left", "right")
	
	# Check if the player rapidly changed direction on the ground
#	if is_on_floor() and not is_sitting and abs(velocity.x) > 150.0:
#		# Check if holding the OPPOSITE direction of current high-speed movement
#		if (direction > 0 and velocity.x < -100) or (direction < 0 and velocity.x > 100):
#			apply_squash_and_stretch(Vector2(0.8, 1.2), 0.05, 0.1)
	
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
	
	apply_squash_and_stretch(Vector2(0.9, 1), 0.04, 0.18)
	
	if hurt_sounds.size() > 0:
		hurt_sfx.stream = hurt_sounds.pick_random()
		hurt_sfx.play()

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
		tw_death.tween_property(rant, "modulate", Color(50.0, 50.0, 50.0, 1.0), 0.1)
		tw_death.tween_property(rant, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
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
	tw.tween_property(rant, "modulate", Color(50.0, 50.0, 50.0, 1.0), 0.1)
	tw.tween_property(rant, "modulate", Color(1.0, 1.0, 1.0, 1.0), 0.1)
	tw.set_loops(3)

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
	sit_sfx.stream = sit_sounds.pick_random()
	sit_sfx.play()

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
	
func handle_footstep_sfx(is_running: bool) -> void:
	# 1. Detect if player just switched between walk <-> run mid-movement
	var state_changed: bool = (is_running != is_currently_running)
	is_currently_running = is_running

	# 2. Only play footstep sounds if moving on the ground
	if is_on_floor() and abs(velocity.x) > 1.0:
		# If state changed OR current sound finished, interrupt & start fresh with new pitch/sound
		if state_changed or not walk_sfx.playing:
			walk_sfx.stop() # Immediately cut off the walking sound sequence!
			
			if walk_sounds.size() > 0:
				walk_sfx.stream = walk_sounds.pick_random()
			
			walk_sfx.pitch_scale = 2.0 if is_running else 1.0
			walk_sfx.play()
	else:
		if walk_sfx.playing:
			walk_sfx.stop()

func apply_squash_and_stretch(target_multiplier: Vector2, duration_in: float = 0.06, duration_out: float = 0.12) -> void:
	if squash_tween and squash_tween.is_running():
		squash_tween.kill()

	# Multiply target ratios by your character's actual base scale
	var target_scale = base_scale * target_multiplier

	squash_tween = create_tween()
	# Squash / Stretch phase
	squash_tween.tween_property(rant, "scale", target_scale, duration_in).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Return back to your base Inspector scale!
	squash_tween.tween_property(rant, "scale", base_scale, duration_out).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
