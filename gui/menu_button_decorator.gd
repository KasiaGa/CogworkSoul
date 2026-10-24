extends Node

const DECOR_TEXTURE: Texture2D = preload("res://assets/images/gui/meuDecor3.png")
const DECOR_SIZE := Vector2(42.0, 24.0)
const ACTIVE_SCALE := Vector2(1.15, 1.15)
const TWEEN_DURATION := 0.2
const PULSE_DURATION := 0.55

var edge_inset: float = 32.0

var _target: Control
var _start_decor: TextureRect
var _end_decor: TextureRect
var _decor_active: bool = false
var _mouse_hovered: bool = false
var _decor_tween: Tween
var _pulse_tween: Tween

func _ready() -> void:
	_target = get_parent() as Control
	if _target == null:
		return

	_start_decor = _create_decor(false)
	_end_decor = _create_decor(true)
	_target.add_child(_start_decor)
	_target.add_child(_end_decor)

	if _target is Button:
		var button := _target as Button
		var empty_style := StyleBoxEmpty.new()
		for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			button.add_theme_stylebox_override(style_name, empty_style)
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER

	_target.mouse_entered.connect(_on_mouse_entered)
	_target.mouse_exited.connect(_on_mouse_exited)
	_target.focus_entered.connect(_update_decor_state)
	_target.focus_exited.connect(_update_decor_state)

func _create_decor(is_end: bool) -> TextureRect:
	var decor := TextureRect.new()
	decor.name = "EndDecor" if is_end else "StartDecor"
	decor.texture = DECOR_TEXTURE
	decor.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	decor.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	decor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	decor.z_index = 1
	decor.visible = false
	decor.flip_h = is_end
	decor.pivot_offset = DECOR_SIZE / 2.0
	decor.anchor_top = 0.5
	decor.anchor_bottom = 0.5
	decor.offset_top = -DECOR_SIZE.y / 2.0
	decor.offset_bottom = DECOR_SIZE.y / 2.0
	if is_end:
		decor.anchor_left = 1.0
		decor.anchor_right = 1.0
		decor.offset_left = -(edge_inset + DECOR_SIZE.x)
		decor.offset_right = -edge_inset
	else:
		decor.anchor_left = 0.0
		decor.anchor_right = 0.0
		decor.offset_left = edge_inset
		decor.offset_right = edge_inset + DECOR_SIZE.x
	return decor

func _on_mouse_entered() -> void:
	_mouse_hovered = true
	_update_decor_state()

func _on_mouse_exited() -> void:
	_mouse_hovered = false
	_update_decor_state()

func _update_decor_state() -> void:
	if _target == null:
		return
	var should_be_active := _mouse_hovered or _target.has_focus()
	if should_be_active != _decor_active:
		_decor_active = should_be_active
		_animate_decor(should_be_active)
	if _decor_active:
		if _mouse_hovered:
			_start_decor_pulse()
		elif _pulse_tween and _pulse_tween.is_valid():
			_animate_decor(true)

func _animate_decor(active: bool) -> void:
	if _decor_tween and _decor_tween.is_valid():
		_decor_tween.kill()
	if _pulse_tween and _pulse_tween.is_valid():
		_pulse_tween.kill()
	_pulse_tween = null
	if active:
		_start_decor.show()
		_end_decor.show()
		if _mouse_hovered:
			_start_decor_pulse()
			return

	var target_scale := ACTIVE_SCALE if active else Vector2.ONE
	_decor_tween = create_tween().set_parallel(true)
	_decor_tween.set_trans(Tween.TRANS_SINE)
	_decor_tween.set_ease(Tween.EASE_OUT)
	_decor_tween.tween_property(_start_decor, "scale", target_scale, TWEEN_DURATION)
	_decor_tween.tween_property(_end_decor, "scale", target_scale, TWEEN_DURATION)
	if not active:
		_decor_tween.chain().tween_callback(_hide_decor_if_inactive)

func _start_decor_pulse() -> void:
	if _pulse_tween and _pulse_tween.is_valid():
		return
	if _decor_tween and _decor_tween.is_valid():
		_decor_tween.kill()
	_start_decor.show()
	_end_decor.show()
	_pulse_tween = create_tween().set_loops()
	_pulse_tween.set_trans(Tween.TRANS_SINE)
	_pulse_tween.set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(_start_decor, "scale", ACTIVE_SCALE, PULSE_DURATION)
	_pulse_tween.parallel().tween_property(_end_decor, "scale", ACTIVE_SCALE, PULSE_DURATION)
	_pulse_tween.chain().tween_property(_start_decor, "scale", Vector2.ONE, PULSE_DURATION)
	_pulse_tween.parallel().tween_property(_end_decor, "scale", Vector2.ONE, PULSE_DURATION)

func _hide_decor_if_inactive() -> void:
	if not _decor_active:
		_start_decor.hide()
		_end_decor.hide()