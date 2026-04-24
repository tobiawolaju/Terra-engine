extends Node2D

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"

var _summary_label: Label
var _entries_label: Label
var _status_label: Label


func _ready() -> void:
	WavedashFlow.ensure_initialized()
	_build_ui()
	_render_summary()
	_status_label.text = "Loading leaderboard..."
	await _load_entries()


func _input(event: InputEvent) -> void:
	if ScreenFader.is_transitioning():
		return
	if event.is_action_pressed("ui_cancel"):
		await ScreenFader.change_scene(MAIN_MENU_SCENE)
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
			await ScreenFader.change_scene(MAIN_MENU_SCENE)


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.12, 0.16, 0.14, 1.0)
	layer.add_child(bg)

	var title := Label.new()
	title.text = "Leaderboard"
	title.position = Vector2(24, 24)
	title.add_theme_font_size_override("font_size", 56)
	layer.add_child(title)

	_summary_label = Label.new()
	_summary_label.position = Vector2(24, 100)
	_summary_label.size = Vector2(1050, 80)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.add_theme_font_size_override("font_size", 26)
	layer.add_child(_summary_label)

	_entries_label = Label.new()
	_entries_label.position = Vector2(24, 190)
	_entries_label.size = Vector2(1050, 380)
	_entries_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_entries_label.add_theme_font_size_override("font_size", 22)
	layer.add_child(_entries_label)

	_status_label = Label.new()
	_status_label.position = Vector2(24, 590)
	_status_label.size = Vector2(1050, 52)
	_status_label.add_theme_font_size_override("font_size", 20)
	layer.add_child(_status_label)


func _render_summary() -> void:
	var username: String = WavedashFlow.get_username()
	var seconds: int = WavedashFlow.last_survival_seconds
	var rank: int = WavedashFlow.last_rank
	var rank_text := "N/A"
	if rank > 0:
		rank_text = str(rank)
	_summary_label.text = "Player: @%s    Survival: %ss    Rank: %s" % [username, seconds, rank_text]


func _load_entries() -> void:
	var response: Dictionary = await WavedashFlow.fetch_top_entries(10)
	if not bool(response.get("success", false)):
		_entries_label.text = "No leaderboard data available yet."
		_status_label.text = "Click anywhere to return to menu."
		return

	_entries_label.text = _format_entries(WavedashFlow.last_entries)
	_status_label.text = "Click anywhere to return to menu."


func _format_entries(entries: Array) -> String:
	if entries.is_empty():
		return "No scores posted yet."

	var lines: PackedStringArray = []
	for index in range(entries.size()):
		var entry: Variant = entries[index]
		if entry is Dictionary:
			var e := entry as Dictionary
			var rank: int = int(e.get("rank", index + 1))
			var username: String = str(e.get("username", "unknown"))
			var score: int = int(e.get("score", 0))
			lines.append("%2d. @%s  -  %ss" % [rank, username, score])
	return "\n".join(lines)
