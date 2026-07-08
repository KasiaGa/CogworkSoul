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

const SPEED = 300.0
const RUN_SPEED = 600.0
const JUMP_VELOCITY = -1400.0

func _ready():
	currentHealth = Global.player_current_health
	maxHealth = Global.player_max_health
	currentSilk = Global.player_current_silk
	maxSilk = Global.player_max_silk
	
	if Global.should_reposition:
		global_position = Global.target_position
		#callable(func(): global_position = Global.target_position).call_deferred()
		# Resetujemy zmienną, aby nie teleportować gracza przy zwykłym starcie gry
		Global.should_reposition = false
		play_arrival_animation()
		
	attack_collision.disabled = true


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
	currentHealth -= amount
	
	if currentHealth <= 0:
		# Handle death here! (Resetting to max health for now as per your original code)
		currentHealth = maxHealth
		
	Global.player_current_health = currentHealth
		
	health_container.updateHearts(currentHealth)
	
	# Flashing/Invincibility period (e.g., 1 second of safety)
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

func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1)
