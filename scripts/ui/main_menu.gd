extends Node2D

const GAMEPLAY_SCENE := "res://scenes/gameplay.tscn"
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"

@onready var _solo_label: Label = $CanvasLayer/solo
@onready var _leaderboard_label: Label = $CanvasLayer/leaderboard
@onready var _username_label: Label = $CanvasLayer/username


func _ready() -> void:
	WavedashFlow.ensure_initialized()
	_update_username()
	if not WavedashFlow.username_updated.is_connected(_on_username_updated):
		WavedashFlow.username_updated.connect(_on_username_updated)


func _exit_tree() -> void:
	if WavedashFlow.username_updated.is_connected(_on_username_updated):
		WavedashFlow.username_updated.disconnect(_on_username_updated)


func _input(event: InputEvent) -> void:
	if ScreenFader.is_transitioning():
		return
	if not (event is InputEventMouseButton):
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT or not mouse_event.pressed:
		return

	var cursor_pos: Vector2 = get_viewport().get_mouse_position()
	if _solo_label != null and _solo_label.get_global_rect().has_point(cursor_pos):
		await ScreenFader.change_scene_with_loading(GAMEPLAY_SCENE)
	elif _leaderboard_label != null and _leaderboard_label.get_global_rect().has_point(cursor_pos):
		await ScreenFader.change_scene(LEADERBOARD_SCENE)


func _on_username_updated(username: String) -> void:
	_username_label.text = "@" + username


func _update_username() -> void:
	_on_username_updated(WavedashFlow.get_username())
