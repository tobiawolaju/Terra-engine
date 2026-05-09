extends Control

@export var idle_opacity: float = 0.5
@export var active_opacity: float = 1.0
@export var idle_scale: float = 1.0
@export var active_scale: float = 1.2
@export var tween_duration: float = 0.14
@export var auto_enable_focus: bool = true
@export var use_rect_hover_detection: bool = true

var _is_hovered: bool = false
var _is_focused: bool = false
var _tween: Tween


func _ready() -> void:
	if auto_enable_focus and focus_mode == FOCUS_NONE:
		focus_mode = FOCUS_ALL
	if mouse_filter == MOUSE_FILTER_IGNORE:
		mouse_filter = MOUSE_FILTER_PASS

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	_apply_state(false)


func _process(_delta: float) -> void:
	if not use_rect_hover_detection:
		return
	var mouse_pos := get_viewport().get_mouse_position()
	var rect_hovered := get_global_rect().has_point(mouse_pos)
	if rect_hovered != _is_hovered:
		_is_hovered = rect_hovered
		_apply_state()


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_state()


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_state()


func _on_focus_entered() -> void:
	_is_focused = true
	_apply_state()


func _on_focus_exited() -> void:
	_is_focused = false
	_apply_state()


func _apply_state(animated: bool = true) -> void:
	var is_active := _is_hovered or _is_focused
	var target_opacity := active_opacity if is_active else idle_opacity
	var target_scale := active_scale if is_active else idle_scale
	var target_scale_vec := Vector2.ONE * target_scale

	if _tween != null and _tween.is_valid():
		_tween.kill()

	if not animated:
		modulate.a = target_opacity
		scale = target_scale_vec
		return

	_tween = create_tween().set_parallel(true)
	_tween.tween_property(self, "modulate:a", target_opacity, maxf(tween_duration, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", target_scale_vec, maxf(tween_duration, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
