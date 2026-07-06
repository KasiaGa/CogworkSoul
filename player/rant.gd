extends CharacterBody2D
@onready var rant: AnimatedSprite2D = $rant
@onready var dialogue: CanvasLayer = $"../Dialogue"
@onready var health_container: HBoxContainer = $"../CanvasLayer/HealthContainer"

@onready var startHealth: int = 5
@onready var startSilk: int = 0

@export var maxHealth: int = 5
@onready var currentHealth: int = startHealth

@export var maxSilk: int = 5
@onready var currentSilk: int = startSilk

const SPEED = 300.0
const RUN_SPEED = 600.0
const JUMP_VELOCITY = -1400.0

func _ready():
	if Global.should_reposition:
		global_position = Global.target_position
		# Resetujemy zmienną, aby nie teleportować gracza przy zwykłym starcie gry
		Global.should_reposition = false


func _physics_process(delta: float) -> void:
	
	var current_speed = SPEED
	
	if true:
	#if !dialogue.visible :
		if velocity.x > SPEED or velocity.x < -SPEED:
			rant.animation = "run_no_needle"
		elif velocity.x > 1 or velocity.x < -1:
			rant.animation = "walk_no_needle"
		else :
			rant.animation = "idle_no_needle"
			
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
		elif direction == -1.0:
			rant.flip_h = false
			
		handleCollision()
			
func handleCollision():
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		#print_debug(collider.name)
		if (collider.name == "enemy"):
			currentHealth -= 1
			if currentHealth < 0:
				currentHealth = maxHealth
			health_container.updateHearts(currentHealth)
			
			
func _on_health_box_area_entered(area):
	if area.name == "hitBox":
		currentHealth -= 1
		if currentHealth < 0:
			currentHealth = maxHealth
