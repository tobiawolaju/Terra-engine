extends Control
class_name LoadingOverlay

const DEFAULT_FADE_IN_SECONDS := 0.2
const DEFAULT_FADE_OUT_SECONDS := 0.2

@onready var _animation_player: AnimationPlayer = get_node_or_null("AnimationPlayer")
@onready var _progress_bar: ProgressBar = _find_first_progress_bar()


func _ready() -> void:
	set_progress(0.0)
	modulate.a = 1.0


func set_progress(normalized: float) -> void:
	if _progress_bar == null:
		return
	_progress_bar.value = clampf(normalized, 0.0, 1.0) * 100.0


func play_enter() -> void:
	if _animation_player != null and _animation_player.has_animation("fade_in"):
		_animation_player.play("fade_in")
		await _animation_player.animation_finished
		return
	await _tween_alpha(0.0, 1.0, DEFAULT_FADE_IN_SECONDS)


func play_exit() -> void:
	if _animation_player != null and _animation_player.has_animation("fade_out"):
		_animation_player.play("fade_out")
		await _animation_player.animation_finished
		return
	await _tween_alpha(1.0, 0.0, DEFAULT_FADE_OUT_SECONDS)


func _tween_alpha(from_alpha: float, to_alpha: float, duration_seconds: float) -> void:
	modulate.a = from_alpha
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", to_alpha, maxf(duration_seconds, 0.0)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished


func _find_first_progress_bar() -> ProgressBar:
	var matches := find_children("*", "ProgressBar", true, false)
	if matches.is_empty():
		return null
	return matches[0] as ProgressBar
