extends Node2D

@export var move_target: NodePath          # Target node/marker where the player gets dropped (NodePath to Marker2D)
@export var start_area: NodePath = NodePath("")    # Area2D node (NodePath) that acts as the trigger where the player must stand
@export var extend_speed: float = 1.0     # Time in seconds to reach player/target
@export var release_delay: float = 0.3    # Pause before dropping the player

@onready var claw_area: Area2D = $Area2D
@onready var ik_target: Marker2D = $IK_Target

# optional runtime references (resolved from exported NodePaths)
var move_target_node: Node2D = null
var start_area_node: Area2D = null

var initial_ik_position: Vector2
var is_busy: bool = false
var grabbed_player: CharacterBody2D = null
var waiting_player: CharacterBody2D = null
var player_waiting: bool = false

func _ready() -> void:
	initial_ik_position = ik_target.global_position
	claw_area.body_entered.connect(_on_claw_body_entered)

	# resolve move_target and start_area if set in the inspector
	if move_target:
		if has_node(move_target):
			move_target_node = get_node(move_target)
		else:
			# inspector may store something unexpected
			push_warning("MechanicalArm: move_target NodePath does not resolve to a node: %s" % str(move_target))

	if start_area:
		if has_node(start_area):
			start_area_node = get_node(start_area)
			start_area_node.body_entered.connect(_on_start_area_body_entered)
			start_area_node.body_exited.connect(_on_start_area_body_exited)
		else:
			push_warning("MechanicalArm: start_area NodePath does not resolve to a node: %s" % str(start_area))

func _on_claw_body_entered(body: Node2D) -> void:
	if is_busy:
		return
		
	if body.is_in_group("player"):
		grab_player(body)


func _on_start_area_body_entered(body: Node2D) -> void:
	# Player stepped into the trigger area — begin approach sequence
	if is_busy:
		return

	if body.is_in_group("player"):
		player_waiting = true
		waiting_player = body

		# Approach the player / grab point
		var target_pos: Vector2 = waiting_player.global_position
		# if there is a dedicated GrabPoint node (child of this arm), prefer that
		if has_node("GrabPoint"):
			target_pos = get_node("GrabPoint").global_position

		var approach_tween = create_tween()
		approach_tween.tween_property(ik_target, "global_position", target_pos, extend_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		await approach_tween.finished

		# if player is still waiting in the start area, attempt to grab
		if player_waiting and waiting_player and waiting_player.is_in_group("player"):
			grab_player(waiting_player)
		else:
			# return to rest if nobody to grab
			var return_tween = create_tween()
			return_tween.tween_property(ik_target, "global_position", initial_ik_position, extend_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			await return_tween.finished


func _on_start_area_body_exited(body: Node2D) -> void:
	# Player left the trigger area before being grabbed
	if body == waiting_player:
		player_waiting = false
		waiting_player = null

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
	var dest_pos: Vector2 = Vector2.ZERO
	if move_target_node:
		dest_pos = move_target_node.global_position
	elif move_target and has_node(move_target):
		dest_pos = get_node(move_target).global_position
	else:
		push_warning("MechanicalArm: No move_target assigned in Inspector! Using initial position as fallback.")
		dest_pos = initial_ik_position

	var move_tween = create_tween()
	move_tween.tween_property(ik_target, "global_position", dest_pos, extend_speed).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	await move_tween.finished

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
