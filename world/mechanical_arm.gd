extends Node2D

@export var move_target: Node2D          # Target node/marker where the player gets dropped
@export var extend_speed: float = 1.0     # Time in seconds to reach player/target
@export var release_delay: float = 0.3    # Pause before dropping the player

@onready var claw_area: Area2D = $Area2D
@onready var ik_target: Marker2D = $IK_Target

var initial_ik_position: Vector2
var is_busy: bool = false
var grabbed_player: CharacterBody2D = null

func _ready() -> void:
	initial_ik_position = ik_target.global_position
	claw_area.body_entered.connect(_on_claw_body_entered)

func _on_claw_body_entered(body: Node2D) -> void:
	if is_busy:
		return
		
	if body.is_in_group("player"):
		grab_player(body)

func grab_player(player: CharacterBody2D) -> void:
	is_busy = true
	grabbed_player = player
	
	# 1. Disable player physics/movement
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO

	# 2. Keep the player locked to the IK Target (claw tip) during transit
	var follow_tween = create_tween().set_loops()
	follow_tween.tween_callback(func():
		if grabbed_player:
			grabbed_player.global_position = ik_target.global_position
	).set_delay(0.01)

	# 3. Move the IK_Target to the target location (bends the joint automatically!)
	if move_target:
		var move_tween = create_tween()
		move_tween.tween_property(ik_target, "global_position", move_target.global_position, extend_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await move_tween.finished
	else:
		push_warning("MechanicalArm: No move_target assigned in Inspector!")

	# 4. Release player
	await get_tree().create_timer(release_delay).timeout
	follow_tween.kill()
	release_player()

func release_player() -> void:
	if grabbed_player:
		grabbed_player.set_physics_process(true)
		grabbed_player = null

	# 5. Return the IK_Target back to its original rest position
	var return_tween = create_tween()
	return_tween.tween_property(ik_target, "global_position", initial_ik_position, extend_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	await return_tween.finished
	is_busy = false
