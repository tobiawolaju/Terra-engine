extends Node2D

const GAMEPLAY_SCENE: String = "res://scenes/gameplay.tscn"

@onready var _play_button: BaseButton = $CanvasLayer/Play


func _ready() -> void:
	if _play_button != null and not _play_button.pressed.is_connected(_on_play_pressed):
		_play_button.pressed.connect(_on_play_pressed)


func _on_play_pressed() -> void:
	if ScreenFader.is_transitioning():
		return
	await ScreenFader.change_scene_with_loading(GAMEPLAY_SCENE)
