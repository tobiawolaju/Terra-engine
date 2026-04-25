extends CanvasLayer

const LOADING_SCENE := preload("res://scenes/loading.tscn")
const DEFAULT_FADE_OUT_SECONDS := 0.18
const DEFAULT_FADE_IN_SECONDS := 0.26

var _input_blocker: ColorRect
var _loading_overlay: CanvasItem
var _loading_progress_bar: ProgressBar
var _is_transitioning: bool = false


func _ready() -> void:
	layer = 100
	_input_blocker = ColorRect.new()
	_input_blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	_input_blocker.color = Color(0.0, 0.0, 0.0, 1.0)
	_input_blocker.modulate.a = 0.0
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.visible = false
	add_child(_input_blocker)


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
	_input_blocker.visible = true
	await _fade_blocker_to(1.0, fade_out_seconds)

	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		push_error("Failed to change scene to '%s' (error %s)." % [path, str(result)])

	await get_tree().process_frame
	await _fade_blocker_to(0.0, fade_in_seconds)
	_finish_transition()


func change_scene_with_loading(path: String) -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	_input_blocker.visible = true
	_show_loading_overlay()
	await _play_loading_enter()

	var request_result := ResourceLoader.load_threaded_request(path, "PackedScene")
	if request_result != OK:
		push_error("Failed to start threaded load for '%s' (error %s)." % [path, str(request_result)])
		_finish_transition()
		return

	var progress: Array = []
	while true:
		progress.clear()
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if progress.size() > 0:
			_set_loading_progress(float(progress[0]))
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			_set_loading_progress(1.0)
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("Threaded load failed for '%s' (status %s)." % [path, str(status)])
			_finish_transition()
			return
		await get_tree().process_frame

	var loaded_resource := ResourceLoader.load_threaded_get(path)
	if loaded_resource == null or not (loaded_resource is PackedScene):
		push_error("Loaded resource for '%s' is not a PackedScene." % path)
		_finish_transition()
		return

	var result := get_tree().change_scene_to_packed(loaded_resource as PackedScene)
	if result != OK:
		push_error("Failed to change scene to '%s' (error %s)." % [path, str(result)])

	await get_tree().process_frame
	await _play_loading_exit()
	_finish_transition()


func _show_loading_overlay() -> void:
	_hide_loading_overlay()
	var instance := LOADING_SCENE.instantiate()
	if not (instance is CanvasItem):
		push_error("Loading scene root must inherit CanvasItem.")
		return

	_loading_overlay = instance as CanvasItem
	if _loading_overlay is Control:
		var control := _loading_overlay as Control
		control.set_anchors_preset(Control.PRESET_FULL_RECT)
		control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_loading_overlay)
	_loading_progress_bar = _find_loading_progress_bar()
	_set_loading_progress(0.0)


func _hide_loading_overlay() -> void:
	if is_instance_valid(_loading_overlay):
		_loading_overlay.queue_free()
	_loading_overlay = null
	_loading_progress_bar = null


func _finish_transition() -> void:
	_hide_loading_overlay()
	_input_blocker.modulate.a = 0.0
	_input_blocker.visible = false
	_is_transitioning = false


func _play_loading_enter() -> void:
	if not is_instance_valid(_loading_overlay):
		return
	if _loading_overlay.has_method("play_enter"):
		await _loading_overlay.call("play_enter")
		return
	await _tween_loading_alpha(0.0, 1.0, 0.2)


func _play_loading_exit() -> void:
	if not is_instance_valid(_loading_overlay):
		return
	if _loading_overlay.has_method("play_exit"):
		await _loading_overlay.call("play_exit")
		return
	await _tween_loading_alpha(1.0, 0.0, 0.2)


func _set_loading_progress(normalized: float) -> void:
	if is_instance_valid(_loading_overlay) and _loading_overlay.has_method("set_progress"):
		_loading_overlay.call("set_progress", normalized)
		return
	if is_instance_valid(_loading_progress_bar):
		_loading_progress_bar.value = clampf(normalized, 0.0, 1.0) * 100.0


func _tween_loading_alpha(from_alpha: float, to_alpha: float, duration_seconds: float) -> void:
	if not is_instance_valid(_loading_overlay):
		return
	_loading_overlay.modulate.a = from_alpha
	var tween := create_tween()
	tween.tween_property(_loading_overlay, "modulate:a", to_alpha, maxf(duration_seconds, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _fade_blocker_to(target_alpha: float, duration_seconds: float) -> void:
	var tween := create_tween()
	tween.tween_property(_input_blocker, "modulate:a", clampf(target_alpha, 0.0, 1.0), maxf(duration_seconds, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _find_loading_progress_bar() -> ProgressBar:
	if not is_instance_valid(_loading_overlay):
		return null
	var matches := _loading_overlay.find_children("*", "ProgressBar", true, false)
	if matches.is_empty():
		return null
	return matches[0] as ProgressBar
