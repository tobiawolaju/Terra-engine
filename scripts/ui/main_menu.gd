extends Node2D

const GAMEPLAY_SCENE := "res://scenes/gameplay.tscn"
const LEADERBOARD_SCENE := "res://scenes/leaderboard.tscn"

@onready var _play_button: BaseButton = $CanvasLayer/Play
@onready var _leaderboard_button: BaseButton = $CanvasLayer/Leaderboard
@onready var _exit_button: BaseButton = $CanvasLayer/Exit
@onready var _username_label: Label = $CanvasLayer/username


func _ready() -> void:
	WavedashFlow.ensure_initialized()
	_update_username()
	if not WavedashFlow.username_updated.is_connected(_on_username_updated):
		WavedashFlow.username_updated.connect(_on_username_updated)
	if _play_button != null and not _play_button.pressed.is_connected(_on_play_pressed):
		_play_button.pressed.connect(_on_play_pressed)
	if _leaderboard_button != null and not _leaderboard_button.pressed.is_connected(_on_leaderboard_pressed):
		_leaderboard_button.pressed.connect(_on_leaderboard_pressed)
	if _exit_button != null and not _exit_button.pressed.is_connected(_on_exit_pressed):
		_exit_button.pressed.connect(_on_exit_pressed)


func _exit_tree() -> void:
	if WavedashFlow.username_updated.is_connected(_on_username_updated):
		WavedashFlow.username_updated.disconnect(_on_username_updated)


func _on_username_updated(username: String) -> void:
	_username_label.text = "@" + username


func _update_username() -> void:
	_on_username_updated(WavedashFlow.get_username())


func _on_play_pressed() -> void:
	if ScreenFader.is_transitioning():
		return
	await ScreenFader.change_scene_with_loading(GAMEPLAY_SCENE)


func _on_leaderboard_pressed() -> void:
	if ScreenFader.is_transitioning():
		return
	await ScreenFader.change_scene(LEADERBOARD_SCENE)


func _on_exit_pressed() -> void:
	get_tree().quit()
