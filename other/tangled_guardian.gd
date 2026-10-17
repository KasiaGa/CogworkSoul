extends CharacterBody2D

signal defeated

enum AttackState { COOLDOWN, TELEGRAPH, ACTIVE }
enum AttackKind { SHORT_STRIKE, LONG_SPAN, JUMP_LEFT, JUMP_RIGHT, JUMP_SPIN }

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
@export var short_reach: float = 650.0
@export var long_reach: float = 2800.0
@export var spin_radius: float = 500.0
@export var jump_horizontal_speed: float = 220.0
@export_range(0.0, 1.0) var far_jump_chance: float = 0.5
@export var far_jump_multiplier: float = 5.0
@export var jump_velocity: float = -1400.0
@export var arena_left_limit: float = -1080.0
@export var arena_right_limit: float = 2240.0

const INTRO_SCREEN_X_FRACTION: float = 0.75
const INTRO_FREEZE_DURATION: float = 1.2
const NEEDLE_HITS_FOR_RETALIATION: int = 5
const SPIN_ROTATION_SPEED: float = 20.0
const SPIN_ATTACK_DURATION: float = 1.25
const MAX_JUMP_ATTACK_DURATION: float = 4.0

var current_health: int = 100
var attack_state: int = AttackState.COOLDOWN
var attack_kind: int = AttackKind.SHORT_STRIKE
var attack_timer: float = 1.0
var facing_direction: float = 1.0
var last_attack_kind: int = -1
var hit_player_this_attack: bool = false
var active_jump_horizontal_speed: float = 0.0
var active_jump_attack_elapsed: float = 0.0
var needle_hits_since_retaliation: int = 0
var retaliation_ready: bool = false
var retaliation_attack_in_progress: bool = false
var base_sprite_color: Color
var hit_flash_tween: Tween
var intro_started: bool = false
var intro_in_progress: bool = false

func _ready() -> void:
	current_health = max_health
	base_sprite_color = guardian_sprite.modulate
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
	_update_attack_movement(delta)
	attack_timer -= delta
	match attack_state:
		AttackState.COOLDOWN:
			if attack_timer <= 0.0 and is_on_floor():
				_begin_attack()
		AttackState.TELEGRAPH:
			if attack_timer <= 0.0:
				_activate_attack()
		AttackState.ACTIVE:
			if _is_jump_attack():
				active_jump_attack_elapsed += delta
			if attack_kind == AttackKind.JUMP_SPIN:
				cable_visual.rotation += delta * SPIN_ROTATION_SPEED
			_check_player_hit()
			if attack_timer <= 0.0 and (not _is_jump_attack() or is_on_floor() or active_jump_attack_elapsed >= MAX_JUMP_ATTACK_DURATION):
				_finish_attack()

func _wait_for_player_to_approach(delta: float) -> void:
	var viewport := get_viewport()
	var camera := viewport.get_camera_2d()
	var intro_position_reached := camera == null
	if camera:
		var screen_world_width := viewport.get_visible_rect().size.x / camera.zoom.x
		var screen_left_world_x := camera.get_screen_center_position().x - screen_world_width * 0.5
		var intro_trigger_world_x := screen_left_world_x + screen_world_width * INTRO_SCREEN_X_FRACTION
		intro_position_reached = global_position.x >= screen_left_world_x and global_position.x <= intro_trigger_world_x
	velocity.x = 0.0
	if is_on_floor():
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
	_clamp_to_arena()
	if is_on_floor() and intro_position_reached:
		_start_boss_intro()

func _update_attack_movement(delta: float) -> void:
	var horizontal_jump_direction := 0.0
	if attack_state == AttackState.ACTIVE:
		if attack_kind == AttackKind.JUMP_LEFT:
			horizontal_jump_direction = -1.0
		elif attack_kind == AttackKind.JUMP_RIGHT:
			horizontal_jump_direction = 1.0
	velocity.x = horizontal_jump_direction * active_jump_horizontal_speed
	if is_on_floor() and velocity.y >= 0.0:
		velocity.y = 0.0
	else:
		velocity += get_gravity() * delta
	move_and_slide()
	_clamp_to_arena()
	if global_position.x <= arena_left_limit and velocity.x < 0.0:
		velocity.x = 0.0
	elif global_position.x >= arena_right_limit and velocity.x > 0.0:
		velocity.x = 0.0

func _is_jump_attack() -> bool:
	return attack_kind == AttackKind.JUMP_LEFT or attack_kind == AttackKind.JUMP_RIGHT or attack_kind == AttackKind.JUMP_SPIN

func _clamp_to_arena() -> void:
	if arena_left_limit <= arena_right_limit:
		global_position.x = clampf(global_position.x, arena_left_limit, arena_right_limit)

func _get_player() -> Node2D:
	return get_tree().get_first_node_in_group("player") as Node2D

func _begin_attack() -> void:
	if retaliation_ready:
		attack_kind = AttackKind.LONG_SPAN
		retaliation_ready = false
		retaliation_attack_in_progress = true
	else:
		retaliation_attack_in_progress = false
		attack_kind = randi_range(0, AttackKind.JUMP_SPIN)
		if attack_kind == last_attack_kind:
			attack_kind = (attack_kind + 1) % (AttackKind.JUMP_SPIN + 1)
	last_attack_kind = attack_kind
	if attack_kind == AttackKind.JUMP_LEFT:
		facing_direction = -1.0
	elif attack_kind == AttackKind.JUMP_RIGHT:
		facing_direction = 1.0
	else:
		var player := _get_player()
		if player:
			facing_direction = sign(player.global_position.x - global_position.x)
			if facing_direction == 0.0:
				facing_direction = 1.0
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
	if _is_jump_attack():
		velocity.y = jump_velocity
		active_jump_attack_elapsed = 0.0
	if attack_kind == AttackKind.JUMP_LEFT or attack_kind == AttackKind.JUMP_RIGHT:
		active_jump_horizontal_speed = jump_horizontal_speed
		if randf() < far_jump_chance:
			active_jump_horizontal_speed *= far_jump_multiplier
	if attack_kind == AttackKind.JUMP_LEFT or attack_kind == AttackKind.JUMP_RIGHT:
		cable_visual.visible = false
	if attack_kind == AttackKind.JUMP_SPIN:
		attack_timer = SPIN_ATTACK_DURATION
	elif attack_kind == AttackKind.JUMP_LEFT or attack_kind == AttackKind.JUMP_RIGHT:
		attack_timer = 0.45
	else:
		attack_timer = 0.3
	cable_visual.default_color = Color(1.0, 0.16, 0.08, 1.0)
	cable_visual.width = 26.0

func _finish_attack() -> void:
	cable_visual.visible = false
	velocity.x = 0.0
	active_jump_horizontal_speed = 0.0
	active_jump_attack_elapsed = 0.0
	attack_state = AttackState.COOLDOWN
	attack_timer = 0.0 if retaliation_ready else attack_cooldown
	retaliation_attack_in_progress = false

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
		AttackKind.JUMP_LEFT:
			return PackedVector2Array([
				Vector2(0, -15),
				Vector2(-110, -80),
				Vector2(-230, -190)
			])
		AttackKind.JUMP_RIGHT:
			return PackedVector2Array([
				Vector2(0, -15),
				Vector2(110, -80),
				Vector2(230, -190)
			])
		AttackKind.JUMP_SPIN:
			return PackedVector2Array([
				Vector2(0, 0),
				Vector2(90, -50),
				Vector2(165, 35),
				Vector2(spin_radius, 0)
			])
	return PackedVector2Array()

func _check_player_hit() -> void:
	if hit_player_this_attack or not cable_visual.visible:
		return
	var player := _get_player()
	if player == null or not player.has_method("take_damage"):
		return
	if bool(player.get("is_invincible")):
		return
	if _cable_touches_player(player):
		player.call("take_damage", attack_damage)
		hit_player_this_attack = true

func _cable_touches_player(player: Node2D) -> bool:
	var player_collision := player.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var player_axis_start := player.global_position
	var player_axis_end := player.global_position
	var player_radius := 24.0
	if player_collision and player_collision.shape is CapsuleShape2D:
		var player_capsule := player_collision.shape as CapsuleShape2D
		var capsule_axis_offset := player_collision.global_transform.y * maxf(0.0, player_capsule.height * 0.5 - player_capsule.radius)
		player_axis_start = player_collision.global_position - capsule_axis_offset
		player_axis_end = player_collision.global_position + capsule_axis_offset
		var player_scale := player_collision.global_scale
		player_radius = player_capsule.radius * maxf(absf(player_scale.x), absf(player_scale.y))

	var cable_scale := cable_visual.global_scale
	var cable_radius := cable_visual.width * 0.5 * maxf(absf(cable_scale.x), absf(cable_scale.y))
	var contact_distance := player_radius + cable_radius
	for point_index in range(cable_visual.points.size() - 1):
		var cable_start := cable_visual.to_global(cable_visual.points[point_index])
		var cable_end := cable_visual.to_global(cable_visual.points[point_index + 1])
		if _segments_within_distance(cable_start, cable_end, player_axis_start, player_axis_end, contact_distance):
			return true
	return false

func _segments_within_distance(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2, distance: float) -> bool:
	if _segments_intersect(a_start, a_end, b_start, b_end):
		return true
	var minimum_distance_squared := minf(
		minf(_point_to_segment_distance_squared(a_start, b_start, b_end), _point_to_segment_distance_squared(a_end, b_start, b_end)),
		minf(_point_to_segment_distance_squared(b_start, a_start, a_end), _point_to_segment_distance_squared(b_end, a_start, a_end))
	)
	return minimum_distance_squared <= distance * distance

func _segments_intersect(a_start: Vector2, a_end: Vector2, b_start: Vector2, b_end: Vector2) -> bool:
	var a_direction := a_end - a_start
	var b_direction := b_end - b_start
	var denominator := a_direction.cross(b_direction)
	if is_zero_approx(denominator):
		return false
	var start_offset := b_start - a_start
	var a_ratio := start_offset.cross(b_direction) / denominator
	var b_ratio := start_offset.cross(a_direction) / denominator
	return a_ratio >= 0.0 and a_ratio <= 1.0 and b_ratio >= 0.0 and b_ratio <= 1.0

func _point_to_segment_distance_squared(point: Vector2, segment_start: Vector2, segment_end: Vector2) -> float:
	var segment := segment_end - segment_start
	var segment_length_squared := segment.length_squared()
	if is_zero_approx(segment_length_squared):
		return point.distance_squared_to(segment_start)
	var closest_ratio := clampf((point - segment_start).dot(segment) / segment_length_squared, 0.0, 1.0)
	var closest_point := segment_start + segment * closest_ratio
	return point.distance_squared_to(closest_point)

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
		return
	_register_needle_hit()

func _register_needle_hit() -> void:
	if retaliation_attack_in_progress:
		return
	needle_hits_since_retaliation += 1
	if needle_hits_since_retaliation < NEEDLE_HITS_FOR_RETALIATION:
		return
	needle_hits_since_retaliation = 0
	retaliation_ready = true
	if intro_started and not intro_in_progress and attack_state == AttackState.COOLDOWN and is_on_floor():
		_begin_attack()

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
