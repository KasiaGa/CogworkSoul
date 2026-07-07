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
		# Resetujemy zmienną, aby nie teleportować gracza przy zwykłym starcie gry
		Global.should_reposition = false
		
	attack_collision.disabled = true


func _physics_process(delta: float) -> void:
	
	var current_speed = SPEED
	
	if true:
	#if !dialogue.visible :
		if not is_attacking:
			if velocity.x > SPEED or velocity.x < -SPEED:
				rant.animation = "run_no_needle"
			elif velocity.x > 1 or velocity.x < -1:
				rant.animation = "walk_no_needle"
			else :
				rant.animation = "idle_no_needle"
			
		if Input.is_action_just_pressed("attack") and not is_attacking:
			is_attacking = true
			rant.play("attack")
			
			attack_collision.disabled = false # Turn ON the attack hitbox
			
			# Wait for the 0.5s animation duration before letting the player move/attack again
			await get_tree().create_timer(0.5).timeout
			attack_collision.disabled = true # Turn OFF the attack hitbox after 0.5s
			is_attacking = false
			
		if Input.is_action_pressed("run"):
			current_speed = RUN_SPEED		
		
		# Add the gravity.
		if not is_on_floor():
			velocity += get_gravity() * delta
			# rant.animation = "jump"

#		if Input.is_action_just_pressed("attack"):
#			rant.animation = "attack"

		# Handle jump.
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_VELOCITY

		# Get the input direction and handle the movement/deceleration.
		# As good practice, you should replace UI actions with custom gameplay actions.
		var direction := Input.get_axis("left", "right")
		if direction:
			velocity.x = direction * current_speed
		else:
			velocity.x = move_toward(velocity.x, 0, current_speed)

		move_and_slide()
		
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


func _on_attack_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(1)
