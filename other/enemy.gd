extends CharacterBody2D
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export var speed = 100
@export var limit = 0.5
@export var endPoint: Marker2D

var startPosition
var endPosition

@export var max_health: int = 3
var current_health: int = max_health

func _ready():
	startPosition = position
	#endPosition = startPosition + Vector2(200, 0)
	endPosition = endPoint.global_position
	animated_sprite_2d.flip_h = true
	
func take_damage(amount: int):
	current_health -= amount
	
	# Visual feedback: Flash white quickly when hit
	var tween = create_tween()
	tween.tween_property(animated_sprite_2d, "modulate", Color(100, 100, 100), 0.1)
	tween.tween_property(animated_sprite_2d, "modulate", Color(1, 1, 1), 0.1)
	
	if current_health <= 0:
		queue_free() # Makes the enemy disappear completely
	
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
