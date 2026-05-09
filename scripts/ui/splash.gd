extends Node2D

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const SPLASH_SECONDS := 1.6


func _ready() -> void:
	WavedashFlow.ensure_initialized()
	await get_tree().create_timer(SPLASH_SECONDS).timeout
	await ScreenFader.change_scene(MAIN_MENU_SCENE)
