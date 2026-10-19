extends CanvasLayer

@export_range(0.0, 1.0, 0.01) var strength: float = 0.5
@export_range(0.0, 1.0, 0.01) var radius: float = 0.3
@export_range(0.01, 1.0, 0.01) var softness: float = 0.5

const VIGNETTE_SHADER: Shader = preload("res://world/room_vignette.gdshader")

func _ready() -> void:
	if strength <= 0.0:
		return

	var overlay := ColorRect.new()
	overlay.name = "VignetteOverlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 4096

	var material := ShaderMaterial.new()
	material.shader = VIGNETTE_SHADER
	material.set_shader_parameter("strength", strength)
	material.set_shader_parameter("radius", radius)
	material.set_shader_parameter("softness", softness)
	overlay.material = material
	add_child(overlay)