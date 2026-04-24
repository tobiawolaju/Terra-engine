extends CanvasLayer

const DEFAULT_FADE_OUT_SECONDS := 0.18
const DEFAULT_FADE_IN_SECONDS := 0.26

var _overlay: ColorRect
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 100
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.0, 0.0, 0.0, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func is_transitioning() -> bool:
	return _is_transitioning


func change_scene(
	path: String,
	fade_out_seconds: float = DEFAULT_FADE_OUT_SECONDS,
	fade_in_seconds: float = DEFAULT_FADE_IN_SECONDS
) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	await _fade_to_alpha(1.0, fade_out_seconds)
	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Failed to change scene to '%s' (error %s)." % [path, str(result)])

	await get_tree().process_frame
	await _fade_to_alpha(0.0, fade_in_seconds)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false


func _fade_to_alpha(target_alpha: float, duration_seconds: float) -> void:
	var safe_duration := maxf(duration_seconds, 0.0)
	if safe_duration == 0.0:
		_overlay.color.a = target_alpha
		return
	if is_equal_approx(_overlay.color.a, target_alpha):
		return

	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", target_alpha, safe_duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
