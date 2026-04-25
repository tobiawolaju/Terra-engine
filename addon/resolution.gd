extends Node

# Runtime resolution manager for autoload use.
# Use set_render_scale() for performance tuning without shrinking UI.

const MIN_RENDER_SCALE: float = 0.5
const MAX_RENDER_SCALE: float = 1.0
const DEFAULT_RENDER_SCALE: float = 1.0

func _ready() -> void:
	set_render_scale(DEFAULT_RENDER_SCALE)

func set_render_scale(scale: float, mode: int = Viewport.SCALING_3D_MODE_BILINEAR) -> float:
	var clamped: float = clampf(scale, MIN_RENDER_SCALE, MAX_RENDER_SCALE)
	var vp: Viewport = get_viewport()
	vp.scaling_3d_mode = mode
	vp.scaling_3d_scale = clamped
	return clamped

func set_window_resolution(width: int, height: int) -> Vector2i:
	var size := Vector2i(maxi(1, width), maxi(1, height))
	DisplayServer.window_set_size(size)
	return size

func apply_quality_preset(preset: String) -> float:
	match preset.to_lower():
		"performance":
			return set_render_scale(0.65)
		"balanced":
			return set_render_scale(0.8)
		"quality":
			return set_render_scale(1.0)
		_:
			return set_render_scale(DEFAULT_RENDER_SCALE)

func get_render_scale() -> float:
	return get_viewport().scaling_3d_scale
