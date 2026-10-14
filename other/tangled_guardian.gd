extends CharacterBody2D

enum AttackState { COOLDOWN, TELEGRAPH, ACTIVE }
enum AttackKind { SHORT_STRIKE, LONG_SPAN, CABLE_SPIN }

@onready var cable_visual: Line2D = $CableVisual
@onready var guardian_sprite: Sprite2D = $Sprite2D
@onready var health_bar = get_node_or_null("../CanvasLayer/BossHealthBar")
@onready var boss_title = get_node_or_null("../CanvasLayer/BossTitle")

@export var max_health: int = 100
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2
@export var telegraph_time: float = 0.75
@export var short_reach: float = 260.0
@export var long_reach: float = 1050.0
@export var spin_radius: float = 245.0

var current_health: int = 100
var attack_state: int = AttackState.COOLDOWN
var attack_kind: int = AttackKind.SHORT_STRIKE
var attack_timer: float = 1.0
var facing_direction: float = 1.0
var last_attack_kind: int = -1
var hit_player_this_attack: bool = false
var base_sprite_color: Color

func _ready() -> void:
	current_health = max_health
	base_sprite_color = guardian_sprite.modulate
	cable_visual.visible = false
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if boss_title:
		boss_title.text = "TANGLED GUARDIAN"

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	attack_timer -= delta
	match attack_state:
		AttackState.COOLDOWN:
			if attack_timer <= 0.0:
				_begin_attack()
		AttackState.TELEGRAPH:
			if attack_timer <= 0.0:
				_activate_attack()
		AttackState.ACTIVE:
			if attack_kind == AttackKind.CABLE_SPIN:
				cable_visual.rotation += delta * 8.0
			_check_player_hit()
			if attack_timer <= 0.0:
				_finish_attack()

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _begin_attack() -> void:
	var player := _get_player()
	if player:
		facing_direction = sign(player.global_position.x - global_position.x)
		if facing_direction == 0.0:
			facing_direction = 1.0

	attack_kind = randi_range(0, 2)
	if attack_kind == last_attack_kind:
		attack_kind = (attack_kind + 1) % 3
	last_attack_kind = attack_kind
	guardian_sprite.flip_h = facing_direction > 0.0
	hit_player_this_attack = false
	attack_state = AttackState.TELEGRAPH
	attack_timer = telegraph_time
	cable_visual.rotation = 0.0
	cable_visual.points = _get_attack_line_points()
	cable_visual.default_color = Color(1.0, 0.72, 0.18, 0.9)
	cable_visual.width = 12.0
	cable_visual.visible = true

func _activate_attack() -> void:
	attack_state = AttackState.ACTIVE
	attack_timer = 0.9 if attack_kind == AttackKind.CABLE_SPIN else 0.3
	cable_visual.default_color = Color(1.0, 0.16, 0.08, 1.0)
	cable_visual.width = 20.0

func _finish_attack() -> void:
	cable_visual.visible = false
	attack_state = AttackState.COOLDOWN
	attack_timer = attack_cooldown

func _get_attack_line_points() -> PackedVector2Array:
	match attack_kind:
		AttackKind.SHORT_STRIKE:
			return PackedVector2Array([
				Vector2(0, -15),
				Vector2(facing_direction * 95, -85),
				Vector2(facing_direction * short_reach, 20)
			])
		AttackKind.LONG_SPAN:
			return PackedVector2Array([
				Vector2(0, -15),
				Vector2(facing_direction * 180, -55),
				Vector2(facing_direction * 520, 5),
				Vector2(facing_direction * long_reach, 0)
			])
		AttackKind.CABLE_SPIN:
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(90, -50),
				Vector2(165, 35),
				Vector2(spin_radius, 0)
			])
	return PackedVector2Array()

func _check_player_hit() -> void:
	if hit_player_this_attack:
		return
	var player := _get_player()
	if player == null or not player.has_method("take_damage"):
		return
	if bool(player.get("is_invincible")):
		return

	var player_offset: Vector2 = to_local(player.global_position)
	var hits_player := false
	match attack_kind:
		AttackKind.SHORT_STRIKE:
			hits_player = (
				player_offset.x * facing_direction >= -35.0
				and player_offset.x * facing_direction <= short_reach
				and abs(player_offset.y) <= 125.0
			)
		AttackKind.LONG_SPAN:
			hits_player = (
				player_offset.x * facing_direction >= 0.0
				and player_offset.x * facing_direction <= long_reach
				and abs(player_offset.y) <= 65.0
			)
		AttackKind.CABLE_SPIN:
			hits_player = abs(player_offset.length() - spin_radius) <= 90.0

	if hits_player:
		player.call("take_damage", attack_damage)
		hit_player_this_attack = true

func take_damage(amount: int) -> void:
	if current_health <= 0:
		return
	current_health = max(0, current_health - amount)
	if health_bar:
		health_bar.value = current_health

	var tween := create_tween()
	tween.tween_property(guardian_sprite, "modulate", Color(1.5, 0.35, 0.25, 1), 0.08)
	tween.tween_property(guardian_sprite, "modulate", base_sprite_color, 0.14)
	if current_health == 0:
		_die()

func _die() -> void:
	cable_visual.visible = false
	if health_bar:
		health_bar.visible = false
	if boss_title:
		boss_title.text = "TANGLED GUARDIAN DEFEATED"
		boss_title.visible = true
	queue_free()