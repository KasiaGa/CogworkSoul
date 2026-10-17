extends CharacterBody2D

signal defeated

enum AttackState { COOLDOWN, TELEGRAPH, ACTIVE }
enum AttackKind { SHORT_STRIKE, LONG_SPAN, CABLE_SPIN }

@onready var cable_visual: Line2D = $CableVisual
@onready var guardian_sprite: Sprite2D = $Sprite2D
@onready var health_bar = get_node_or_null("../CanvasLayer/BossHealthBar")
@onready var boss_title = get_node_or_null("../CanvasLayer/BossTitle")
@onready var silk_container = get_node_or_null("../CanvasLayer/SilkContainer")
@onready var intro_label = get_node_or_null("../CanvasLayer/BossIntroTitle")

@export var max_health: int = 100
@export var attack_damage: int = 1
@export var attack_cooldown: float = 1.2
@export var telegraph_time: float = 0.75
@export var short_reach: float = 400.0
@export var long_reach: float = 1500.0
@export var spin_radius: float = 360.0
@export var movement_speed: float = 180.0
@export var jump_velocity: float = -1400.0
@export var jump_interval_min: float = 2.0
@export var jump_interval_max: float = 3.5
@export var preferred_player_distance: float = 285.0
@export var arena_left_limit: float = -1080.0
@export var arena_right_limit: float = 2240.0

const INTRO_CENTER_TOLERANCE: float = 40.0
const INTRO_FREEZE_DURATION: float = 1.2

var current_health: int = 100
var attack_state: int = AttackState.COOLDOWN
var attack_kind: int = AttackKind.SHORT_STRIKE
var attack_timer: float = 1.0
var facing_direction: float = 1.0
var last_attack_kind: int = -1
var hit_player_this_attack: bool = false
var base_sprite_color: Color
var movement_direction: float = 0.0
var movement_choice_timer: float = 0.0
var jump_timer: float = 0.0
var hit_flash_tween: Tween
var intro_started: bool = false
var intro_in_progress: bool = false

func _ready() -> void:
	current_health = max_health
	base_sprite_color = guardian_sprite.modulate
	jump_timer = randf_range(jump_interval_min, jump_interval_max)
	cable_visual.visible = false
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	if boss_title:
		boss_title.text = "TANGLED GUARDIAN"

func _start_boss_intro() -> void:
	if intro_started:
		return
	intro_started = true
	intro_in_progress = true
	var player := _get_player()
	var player_was_transitioning := false
	if player:
		player_was_transitioning = bool(player.get("is_transitioning"))
		player.set("is_transitioning", true)
		player.set("velocity", Vector2.ZERO)
	var was_paused := get_tree().paused
	get_tree().paused = true

	if intro_label:
		intro_label.visible = true
		intro_label.modulate = Color(1.0, 1.0, 1.0, 0.0)
		var title_tween := create_tween()
		title_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		title_tween.tween_property(intro_label, "modulate:a", 1.0, 0.35)
		title_tween.tween_interval(2.4)
		title_tween.tween_property(intro_label, "modulate:a", 0.0, 0.6)
		title_tween.tween_callback(func(): intro_label.visible = false)

	for pulse_index in range(3):
		get_tree().create_timer(float(pulse_index) * 0.24, true).timeout.connect(_create_radiance_pulse)
	await get_tree().create_timer(INTRO_FREEZE_DURATION, true).timeout
	if is_instance_valid(player):
		player.set("is_transitioning", player_was_transitioning)
	intro_in_progress = false
	get_tree().paused = was_paused

func _create_radiance_pulse() -> void:
	var ring := Line2D.new()
	ring.name = "IntroRadiancePulse"
	ring.width = 10.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.95)
	ring.closed = true
	ring.antialiased = true
	var pulse_points := PackedVector2Array()
	for point_index in range(48):
		var angle := TAU * float(point_index) / 48.0
		pulse_points.append(Vector2(cos(angle), sin(angle)) * 180.0)
	ring.points = pulse_points
	ring.position = guardian_sprite.position
	ring.z_index = 4
	ring.scale = Vector2(0.55, 0.55)
	add_child(ring)

	var pulse_tween := create_tween()
	pulse_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	pulse_tween.set_parallel(true)
	pulse_tween.tween_property(ring, "scale", Vector2(2.2, 2.2), 0.72)
	pulse_tween.tween_property(ring, "modulate:a", 0.0, 0.72)
	get_tree().create_timer(0.75, true).timeout.connect(ring.queue_free)

func _physics_process(delta: float) -> void:
	if current_health <= 0:
		return
	if intro_in_progress:
		velocity = Vector2.ZERO
		return
	if not intro_started:
		_wait_for_player_to_approach(delta)
		return
	_update_movement(delta)
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

func _wait_for_player_to_approach(delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	var screen_center_x := camera.get_screen_center_position().x if camera else global_position.x
	velocity.x = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
	_clamp_to_arena()
	if is_on_floor() and absf(screen_center_x - global_position.x) <= INTRO_CENTER_TOLERANCE:
		_start_boss_intro()

func _update_movement(delta: float) -> void:
	var player := _get_player()
	if player:
		var player_offset_x := player.global_position.x - global_position.x
		if abs(player_offset_x) > preferred_player_distance:
			movement_direction = sign(player_offset_x)
		else:
			movement_choice_timer -= delta
			if movement_choice_timer <= 0.0:
				movement_direction = float(randi_range(-1, 1))
				movement_choice_timer = randf_range(0.8, 1.6)

		if attack_state == AttackState.COOLDOWN and not is_zero_approx(player_offset_x):
			guardian_sprite.flip_h = player_offset_x > 0.0
	else:
		movement_choice_timer -= delta
		if movement_choice_timer <= 0.0:
			movement_direction = float(randi_range(-1, 1))
			movement_choice_timer = randf_range(0.8, 1.6)

	if global_position.x <= arena_left_limit:
		movement_direction = maxf(movement_direction, 0.0)
	elif global_position.x >= arena_right_limit:
		movement_direction = minf(movement_direction, 0.0)
	velocity.x = movement_direction * movement_speed

	if is_on_floor():
		velocity.y = 0.0
		jump_timer -= delta
		if jump_timer <= 0.0:
			velocity.y = jump_velocity
			jump_timer = randf_range(jump_interval_min, jump_interval_max)
	else:
		velocity += get_gravity() * delta

	move_and_slide()
	_clamp_to_arena()

func _clamp_to_arena() -> void:
	if arena_left_limit <= arena_right_limit:
		global_position.x = clampf(global_position.x, arena_left_limit, arena_right_limit)

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
	cable_visual.width = 16.0
	cable_visual.visible = true

func _activate_attack() -> void:
	attack_state = AttackState.ACTIVE
	attack_timer = 0.9 if attack_kind == AttackKind.CABLE_SPIN else 0.3
	cable_visual.default_color = Color(1.0, 0.16, 0.08, 1.0)
	cable_visual.width = 26.0

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
	_award_silk_for_hit()
	if health_bar:
		health_bar.value = current_health

	_flash_white()
	if current_health == 0:
		_die()

func _award_silk_for_hit() -> void:
	if Global.player_current_silk >= Global.player_max_silk:
		return
	var player := _get_player()
	if player == null or not player.has_method("set_current_silk"):
		return
	var updated_silk := Global.player_current_silk + 1
	player.call("set_current_silk", updated_silk)
	if silk_container and silk_container.has_method("updateSilk"):
		silk_container.call("updateSilk", updated_silk)

func _flash_white() -> void:
	if hit_flash_tween and hit_flash_tween.is_running():
		hit_flash_tween.kill()
	guardian_sprite.modulate = base_sprite_color
	hit_flash_tween = create_tween()
	hit_flash_tween.tween_property(guardian_sprite, "modulate", Color(100.0, 100.0, 100.0, 1.0), 0.05)
	hit_flash_tween.tween_property(guardian_sprite, "modulate", base_sprite_color, 0.12)

func _die() -> void:
	cable_visual.visible = false
	if health_bar:
		health_bar.visible = false
	if boss_title:
		boss_title.text = "TANGLED GUARDIAN DEFEATED"
		boss_title.visible = true
	if intro_label:
		intro_label.visible = false
	defeated.emit()
	queue_free()
