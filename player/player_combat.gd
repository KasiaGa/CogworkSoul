extends Node

const NEEDLE_DIALOGUE_FILE = preload("res://dialogue/rant_needle.dialogue")
const DEFAULT_ATTACK_DURATION: float = 0.15
const MAX_TRAIL_POINTS: int = 10

@onready var player = get_parent()
@onready var attack_collision: CollisionShape2D = $"../AttackArea/CollisionShape2D"
@onready var attack_rig: Node2D = $"../AttackArea/AttackRig"
@onready var slash_trail: Line2D = $"../AttackArea/AttackRig/SlashTrail"
@onready var brass_trail: Line2D = $"../AttackArea/AttackRig/BrassSlashTrail"
@onready var weapon_tip: Node2D = $"../AttackArea/AttackRig/WeaponTip"
@onready var player_sprite: AnimatedSprite2D = $"../rant"
@onready var attack_animation: AnimationPlayer = $"../AnimationPlayer"
@onready var attack_sfx: AudioStreamPlayer = $"../AttackSfx"

var attack_time_remaining: float = 0.0
var attack_reach_multiplier: float = 1.0
var base_attack_radius: float = 0.0
var base_attack_position: Vector2 = Vector2.ZERO
var brass_slash_equipped: bool = false
var trail_points: Array[Vector2] = []
var hit_targets: Dictionary = {}

func _ready() -> void:
	attack_collision.disabled = true
	var attack_shape := attack_collision.shape as CapsuleShape2D
	if attack_shape:
		var independent_shape := attack_shape.duplicate() as CapsuleShape2D
		attack_collision.shape = independent_shape
		base_attack_radius = independent_shape.radius
		base_attack_position = attack_collision.position
	_sync_attack_modules()

func try_start_attack() -> void:
	if not Input.is_action_just_pressed("attack") or not Global.has_needle:
		return
	if Global.is_dialogue_active:
		return
	if player.get("is_attacking") or player.get("is_dead") or player.get("is_sitting"):
		return
	if player.get("is_transitioning") or player.get("is_wren_active"):
		return

	_sync_attack_modules()
	hit_targets.clear()
	trail_points.clear()
	slash_trail.clear_points()
	brass_trail.clear_points()
	brass_trail.visible = brass_slash_equipped
	player.set("is_attacking", true)

	if not Global.rant_needle_played:
		Global.rant_needle_played = true
		Global.save_game()
		var dialogue = player.get_node_or_null("../CanvasLayer/Dialogue")
		if dialogue and dialogue.has_method("start"):
			dialogue.start(NEEDLE_DIALOGUE_FILE, "rant_needle")

	if attack_animation.is_playing():
		attack_animation.stop()
	attack_animation.play("attack_trail")
	player_sprite.play("attack")
	attack_collision.set_deferred("disabled", false)

	var attack_sounds: Array = player.get("attack_sounds")
	if not attack_sounds.is_empty():
		attack_sfx.stream = attack_sounds.pick_random()
		attack_sfx.play()

	var animation: Animation = attack_animation.get_animation("attack_trail")
	attack_time_remaining = animation.length if animation else DEFAULT_ATTACK_DURATION

func _physics_process(delta: float) -> void:
	if player.get("is_attacking"):
		attack_time_remaining -= delta
		if attack_time_remaining <= 0.0:
			_finish_attack()
	_update_slash_trail()

func _finish_attack() -> void:
	attack_collision.set_deferred("disabled", true)
	player.set("is_attacking", false)
	attack_time_remaining = 0.0

func cancel_attack() -> void:
	attack_collision.set_deferred("disabled", true)
	player.set("is_attacking", false)
	attack_time_remaining = 0.0
	trail_points.clear()
	slash_trail.clear_points()
	brass_trail.clear_points()
	brass_trail.visible = false

func _sync_attack_modules() -> void:
	attack_reach_multiplier = 1.0
	for module_id: String in Global.equipped_modules:
		var module_data: Dictionary = Global.module_database.get(module_id, {})
		attack_reach_multiplier *= float(module_data.get("attack_reach_multiplier", 1.0))
	attack_rig.scale = Vector2(attack_reach_multiplier, 1.0)
	var attack_shape := attack_collision.shape as CapsuleShape2D
	if attack_shape:
		attack_shape.radius = base_attack_radius * attack_reach_multiplier
		attack_collision.position = Vector2(base_attack_position.x * attack_reach_multiplier, base_attack_position.y)
	brass_slash_equipped = Global.is_module_equipped("brass_slash")

func _update_slash_trail() -> void:
	if player.get("is_attacking"):
		trail_points.append(slash_trail.to_local(weapon_tip.global_position))
		if trail_points.size() > MAX_TRAIL_POINTS:
			trail_points.pop_front()
	elif not trail_points.is_empty():
		trail_points.pop_front()

	var points := PackedVector2Array(trail_points)
	slash_trail.points = points
	brass_trail.points = points
	brass_trail.visible = brass_slash_equipped and not trail_points.is_empty()

func _on_attack_area_body_entered(body: Node2D) -> void:
	if not player.get("is_attacking"):
		return
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		_damage_once(body, "take_damage")
	elif body.is_in_group("cocoon") and body.has_method("take_cocoon_damage"):
		_damage_once(body, "take_cocoon_damage")
	elif body.is_in_group("breakable") and body.has_method("take_damage"):
		_damage_once(body, "take_damage")

func _on_attack_area_area_entered(area: Area2D) -> void:
	if not player.get("is_attacking"):
		return
	if area.is_in_group("cocoon") and area.has_method("take_cocoon_damage"):
		_damage_once(area, "take_cocoon_damage")
	if area.is_in_group("breakable") and area.has_method("take_damage"):
		_damage_once(area, "take_damage")

func _damage_once(target: Node, method: StringName) -> void:
	var target_id := target.get_instance_id()
	if hit_targets.has(target_id):
		return
	hit_targets[target_id] = true
	target.call(method, 1)